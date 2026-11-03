// EduT discontinued LiveKit video calling in iOS 1.0.1.
// Keep the legacy endpoint disabled for users of earlier app versions.
Deno.serve((_request: Request) =>
  new Response(JSON.stringify({ error: "Video calling has been discontinued." }), {
    status: 410,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  })
);
