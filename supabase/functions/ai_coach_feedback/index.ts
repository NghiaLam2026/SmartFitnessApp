// supabase/functions/ai_coach_feedback/index.ts
import "https://deno.land/x/dotenv/load.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = "gemini-2.5-flash";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const handler = async (req) => {
  try {
    const { query, user_id, embedding } = await req.json();
    if (!query || !user_id) {
      return new Response(JSON.stringify({ error: "Missing query or user_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" }
      });
    }

    const text = query.toLowerCase();
    const queryEmbedding = embedding ?? Array(768).fill(0.1);

    // ⭐ Intelligent function selection
    let functionName = "match_user_progress"; // default

    if (text.includes("week") || text.includes("recent") || text.includes("7 days")) {
      functionName = "match_user_progress_7days";
    }

    else if (
      text.includes("timeline") ||
      text.includes("chronological") ||
      text.includes("earliest") ||
      text.includes("since") ||
      text.includes("progress over time")
    ) {
      functionName = "match_user_progress_by_date";
    }

    else if (
      text.includes("trend") ||
      text.includes("pattern") ||
      text.includes("overall") ||
      text.includes("improving") ||
      text.includes("declining")
    ) {
      functionName = "match_user_progress_trends";
    }

    console.log("Using SQL function:", functionName);

    // Call selected SQL function
    const { data: results, error } = await supabase.rpc(functionName, {
      query_embedding: queryEmbedding,
      match_count: 5,
      match_user: user_id
    });

    if (error) throw error;

    const summary = results?.length
      ? results.map((r, i) =>
            `${i + 1}. (${new Date(r.date_logged).toDateString()}) `
            + `Steps: ${r.steps_count}, Calories: ${r.calories_burned}, Weight: ${r.weight}`
        ).join("\n")
      : "No logs found.";

    // ---------- Gemini Prompt ----------
    const prompt = `
You are a fitness AI coach helping the user understand their progress.

Here are the matched logs:
${summary}

User question: "${query}"

Give a helpful analysis and recommendations in 3–5 sentences. Mention dates and trends clearly.
`;

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              role: "user",
              parts: [{ text: prompt }]
            }
          ]
        })
      }
    );

    if (!geminiRes.ok) {
      throw new Error(await geminiRes.text());
    }

    const geminiData = await geminiRes.json();
    const output = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

    return new Response(JSON.stringify({ feedback: output }), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    });

  } catch (err) {
    console.error("AI Coach error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
};

Deno.serve(handler);

    
