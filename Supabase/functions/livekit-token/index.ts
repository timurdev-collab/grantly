// LiveKit video calling has been permanently discontinued in EduT.
// Keep this route unavailable for previously installed clients.
Deno.serve((_request: Request) =>
  new Response(JSON.stringify({ error: "Video calling has been discontinued." }), {
    status: 410,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  })
);
