import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

serve(async (req) => {
  try {
    // Debug: ensure env variable is loaded
    console.log("GEMINI_KEY?", Deno.env.get("GEMINI_API_KEY"));

    // Parse JSON request body
    const { record_id, user_id, progress_summary } = await req.json();

    if (!record_id || !user_id || !progress_summary) {
      throw new Error(
        "Missing required fields: record_id, user_id, progress_summary"
      );
    }

    // 1️⃣ Call Gemini Embedding API
    const res = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent?key=" +
        Deno.env.get("GEMINI_API_KEY"),
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "embedding-001",
          content: {
            parts: [{ text: progress_summary }],
          },
        }),
      }
    );

    const data = await res.json();
    console.log("Gemini raw response:", data);

    const embedding = data.embedding?.values;

    if (!embedding) {
      throw new Error("Gemini API returned no embedding: " + JSON.stringify(data));
    }

    // 2️⃣ Save embedding into user_progress_embeddings
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL"),
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    );

    const { error } = await supabase
      .from("user_progress_embeddings")
      .insert({
        user_id,
        progress_id: record_id,
        embedding,
      });

    if (error) throw error;

    // Success
    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Embedding error:", err);
    return new Response(
      JSON.stringify({ error: err.message ?? String(err) }),
      { status: 500 }
    );
  }
});


