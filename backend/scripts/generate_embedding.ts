//this alone sends one text string ("User walked 7,500 steps") to ollama and prints the embedding

// auto_embed_progress.ts
// Automatically generate and store embeddings for user progress logs

//make sure that 
import "https://deno.land/x/dotenv/load.ts";

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// 🔧 Load environment variables
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("❌ Missing Supabase environment variables.");
  Deno.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// 🧠 Helper: Generate embedding from Ollama
async function generateEmbedding(text: string) {
  const res = await fetch("http://localhost:11434/api/embeddings", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "nomic-embed-text",
      prompt: text,
    }),
  });

  if (!res.ok) {
    throw new Error(`Ollama error ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  return data.embedding;
}

// ⚙️ Step 1: Fetch recent progress entries without embeddings
const { data: progressRows, error } = await supabase
  .from("user_progress")
  .select("*")
  .order("date_logged", { ascending: false })
  .limit(5); // or fetch only missing embeddings in a future version

if (error) {
  console.error("❌ Error fetching progress:", error.message);
  Deno.exit(1);
}

if (!progressRows || progressRows.length === 0) {
  console.log("No progress entries found.");
  Deno.exit(0);
}

console.log(`Found ${progressRows.length} progress records.`);

// ⚙️ Step 2: Generate embeddings for each record and insert
for (const row of progressRows) {
  const textSummary = `
  On ${row.date_logged},
  user weighed ${row.weight} kg,
  walked ${row.steps_count} steps,
  and burned ${row.calories_burned} calories.
  `;

  console.log(`Generating embedding for progress_id ${row.progress_id}...`);
  const embedding = await generateEmbedding(textSummary);

  const { error: insertError } = await supabase
    .from("user_progress_embeddings")
    .insert({
      user_id: row.user_id,
      progress_id: row.progress_id,
      embedding,
    });

  if (insertError) {
    console.error(`❌ Failed to insert embedding:`, insertError.message);
  } else {
    console.log(`✅ Embedding stored for progress_id ${row.progress_id}`);
  }
}

console.log("✨ All embeddings processed successfully!");
