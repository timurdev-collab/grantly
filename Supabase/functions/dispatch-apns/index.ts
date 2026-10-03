import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type NotificationRow = {
  id: string;
  user_id: string;
  kind: string;
  title: string;
  body: string;
  scholarship_id: string | null;
  task_id: string | null;
};

type DeviceRow = {
  id: string;
  user_id: string;
  token: string;
  environment: "development" | "production";
};

function base64Url(input: Uint8Array | string) {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;

  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);

  return btoa(binary)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function pemToBytes(pem: string) {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");

  const binary = atob(clean);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function makeApnsJwt(
  teamId: string,
  keyId: string,
  privateKey: string
) {
  const header = base64Url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = base64Url(JSON.stringify({
    iss: teamId,
    iat: Math.floor(Date.now() / 1000)
  }));
  const signingInput = header + "." + claims;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );

  return signingInput + "." + base64Url(new Uint8Array(signature));
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" }
    });
  }

  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const url = Deno.env.get("SUPABASE_URL");

  if (!serviceRole || !url) {
    return new Response(JSON.stringify({ error: "Server configuration unavailable" }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  const admin = createClient(url, serviceRole, {
    auth: { persistSession: false }
  });

  const providedToken = req.headers.get("x-edut-push-token");
  const { data: dispatchConfig, error: dispatchConfigError } = await admin
    .from("notification_dispatch_config")
    .select("cron_token,enabled")
    .eq("id", true)
    .maybeSingle();

  if (
    dispatchConfigError ||
    !dispatchConfig?.enabled ||
    !providedToken ||
    providedToken !== dispatchConfig.cron_token
  ) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" }
    });
  }

  const keyId = Deno.env.get("APNS_KEY_ID");
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
  const teamId = Deno.env.get("APNS_TEAM_ID") ?? "M9L42LN3CG";
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.grantly.app";

  if (!keyId || !privateKey) {
    return new Response(JSON.stringify({
      configured: false,
      error: "APNs credentials are not configured"
    }), {
      status: 503,
      headers: { "Content-Type": "application/json" }
    });
  }

  let body: { limit?: number } = {};
  try {
    body = await req.json();
  } catch {}

  const limit = Math.min(Math.max(body.limit ?? 50, 1), 100);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  const { data: notifications, error: notificationError } = await admin
    .from("app_notifications")
    .select("id,user_id,kind,title,body,scholarship_id,task_id")
    .eq("push_status", "pending")
    .lte("scheduled_for", new Date().toISOString())
    .order("created_at", { ascending: true })
    .limit(limit);

  if (notificationError) {
    return new Response(JSON.stringify({ error: notificationError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  const rows = (notifications ?? []) as NotificationRow[];

  if (!rows.length) {
    return new Response(JSON.stringify({
      configured: true,
      processed: 0,
      sent: 0,
      skipped: 0,
      failed: 0
    }), {
      headers: { "Content-Type": "application/json" }
    });
  }

  const userIds = [...new Set(rows.map((row) => row.user_id))];

  const { data: devices, error: deviceError } = await admin
    .from("push_devices")
    .select("id,user_id,token,environment")
    .in("user_id", userIds);

  if (deviceError) {
    return new Response(JSON.stringify({ error: deviceError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  const deviceRows = (devices ?? []) as DeviceRow[];
  const jwt = await makeApnsJwt(teamId, keyId, privateKey);

  let sent = 0;
  let skipped = 0;
  let failed = 0;

  for (const notification of rows) {
    const targets = deviceRows.filter(
      (device) => device.user_id === notification.user_id
    );

    if (!targets.length) {
      await admin
        .from("app_notifications")
        .update({
          push_status: "skipped",
          push_error: "No registered iOS device"
        })
        .eq("id", notification.id);

      skipped += 1;
      continue;
    }

    let delivered = false;
    const errors: string[] = [];

    for (const device of targets) {
      const host = device.environment === "development"
        ? "https://api.sandbox.push.apple.com"
        : "https://api.push.apple.com";

      const response = await fetch(
        host + "/3/device/" + device.token,
        {
          method: "POST",
          headers: {
            authorization: "bearer " + jwt,
            "apns-topic": bundleId,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "content-type": "application/json"
          },
          body: JSON.stringify({
            aps: {
              alert: {
                title: notification.title,
                body: notification.body
              },
              sound: "default"
            },
            kind: notification.kind,
            notification_id: notification.id,
            scholarship_id: notification.scholarship_id,
            task_id: notification.task_id
          })
        }
      );

      if (response.ok) {
        delivered = true;
        continue;
      }

      const detail = await response.text();
      errors.push(response.status + ": " + detail);

      if (response.status === 410 ||
          (response.status === 400 && detail.includes("BadDeviceToken"))) {
        await admin
          .from("push_devices")
          .delete()
          .eq("id", device.id);
      }
    }

    if (delivered) {
      await admin
        .from("app_notifications")
        .update({
          push_status: "sent",
          push_sent_at: new Date().toISOString(),
          push_error: errors.length ? errors.join(" | ").slice(0, 1000) : null
        })
        .eq("id", notification.id);

      sent += 1;
    } else {
      await admin
        .from("app_notifications")
        .update({
          push_status: "failed",
          push_error: errors.join(" | ").slice(0, 1000)
        })
        .eq("id", notification.id);

      failed += 1;
    }
  }

  return new Response(JSON.stringify({
    configured: true,
    processed: rows.length,
    sent,
    skipped,
    failed
  }), {
    headers: { "Content-Type": "application/json" }
  });
});
