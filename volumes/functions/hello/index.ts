// Beispiel Edge Function fuer Supabase
// Diese Funktion wird unter /functions/v1/hello erreichbar sein

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

interface RequestBody {
  name?: string;
}

serve(async (req: Request) => {
  // CORS Headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let name = "Welt";

    // JSON Body parsen falls vorhanden
    if (req.method === "POST") {
      const body: RequestBody = await req.json();
      if (body.name) {
        name = body.name;
      }
    }

    // Query Parameter pruefen
    const url = new URL(req.url);
    const queryName = url.searchParams.get("name");
    if (queryName) {
      name = queryName;
    }

    const data = {
      message: `Hallo ${name}!`,
      timestamp: new Date().toISOString(),
    };

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
