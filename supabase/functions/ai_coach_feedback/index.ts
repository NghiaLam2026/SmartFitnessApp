// supabase/functions/ai_coach_feedback/index.ts
// AI Personalized Coach Edge Function (final version)

import "https://deno.land/x/dotenv/load.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

//env variables

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const GEMINI_MODEL = "gemini-2.5-flash";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

//type definitions

interface UserProgress {
  progress_id: number;
  user_id: string;
  weight: number;
  calories_burned: number;
  steps_count: number;
  date_logged: string;
  similarity: number;
}

//handler function

const handler = async (req: Request): Promise<Response> => {
  try {
    const { query, user_id, embedding } = await req.json();

    if (!query || !user_id){
      return new Response(JSON.stringify({ error: "Missing 'query' or 'user_id'" }),{
        status: 400,
        headers: {"Content-Type": "application/json"},
      });
    }
    //use provided embedding or fallback dummy vector
    const queryEmbedding = embedding ?? Array(768).fill(0.1);

    //search for similar progress entries
    const {data: results, error} = await supabase
      .rpc<UserProgress>("match_user_progress", {
        query_embedding: queryEmbedding,
        match_count:3,
        match_user:user_id,
      });
      if (error) throw error;
      const summary = 
        results && results.length > 0
          ? results
            .map(
              (r: UserProgress, i: number) =>
                `${i+1}. On ${r.date_logged}, user weighed ${r.weight} kg, walked ${r.steps_count} steps and burned ${r.calories_burned} calories.`
            )
            .join("\n")
          : "No previous logs found.";
    //build gemini promopt dynamically
    let focusPrompt = "";
    const q = query.toLowerCase();

    if(q.includes("weight")){
      focusPrompt = "Focus on analyzing the user's weight changes and explain what it means for their health and fitness goals.";
    } else if (q.includes("steps")){
      focusPrompt = "Focus on evaluating the users steps trends and how they can improve endurance.";
    } else if(q.includes("calories")){
      focusPrompt = "Focus on calorie-burn trends and what they suggest about workout intensity or metabolism.";
    } else if(q.includes("today")|| q.includes("this day")){
      focusPrompt = "Focus on today's progress. summarize the users most recent log, highlight what went well, and suggest one short-term improvement for tomorrow.";
    } else if(q.includes("this week")|| q.includes("week")){
      focusPrompt = "Summarize the users overall weekly progress, comparing the earliest and most recent logs. Highlight trends in weight, steps and calories burned";
    } else if(q.includes("month") || q.includes("overall") || q.includes("recent")){
      focusPrompt = "Give a high-level summary of the users recent overall progress. Identify patterns in actvity and weight consistency.";
    } else{
      focusPrompt = "Provide a general reflection on the user's progress based on all available data.";
    }
    //final gemini prompt
    const prompt = `
you are a personal AI fitness coach. Use this user's recent progress logs to respond helpfully.

Progress logs:
${summary}
User question: "${query}"

${focusPrompt}

Keep the tone supportive, positive and personalized. if trends are visible over time, mention them clearly (e.g., "this week your steps increased by 10%"), Reply in 3-5 sentences.
`;
    const geminiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: {"Content-Type":"application/json"},
        body: JSON.stringify({
          contents: [
            {
              role:"user",
              parts: [{text: prompt}],
            },
          ],
        }),
      }
    );
    console.log("GEMINI_API_KEY loaded?", !!GEMINI_API_KEY);
    if(!geminiRes.ok){
      const errText = await geminiRes.text();
      console.error("gemini raw error:", errText);
      throw new Error(`Gemini API error: ${errText}`);
    }
    const geminiData = await geminiRes.json();
    const text =
      geminiData.candidates?.[0]?.content?.parts?.[0]?.text ??
      "No feedback generated";
    return new Response(JSON.stringify({feedback: text}),{
    headers: {"Content-Type": "application/json"},
    status: 200,
  });
} catch (err){
  console.error("AI coach Error:", err);
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message}), {
      status: 500,
      headers: {"Content-Type": "application/json"},
    });
  }
};  

Deno.serve(handler);
    
