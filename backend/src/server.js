/* eslint-disable no-console */
const path = require('path');
const fs = require('fs');
// Try loading .env from backend/ first; if not found, fall back to repo root .env
require('dotenv').config();
if (!process.env.GEMINI_API_KEY) {
  const backendEnv = path.resolve(__dirname, '..', '.env');
  const rootEnv = path.resolve(__dirname, '..', '..', '.env');
  const candidate = fs.existsSync(backendEnv) ? backendEnv : (fs.existsSync(rootEnv) ? rootEnv : null);
  if (candidate) {
    require('dotenv').config({ path: candidate });
  }
}
const express = require('express');
const cors = require('cors');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { z } = require('zod');

const PORT = parseInt(process.env.PORT || '8000', 10);
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const MODEL_ID = process.env.GEMINI_MODEL_ID || 'gemini-2.5-flash';

if (!GEMINI_API_KEY) {
  console.error('Missing GEMINI_API_KEY');
  process.exit(1);
}

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Request validation
const GenerateSchema = z.object({
  daysPerWeek: z.number().int().min(1).max(7),
  minutesPerSession: z.number().int().min(10).max(120),
  equipment: z.array(z.enum(['none', 'bands', 'dumbbells', 'barbell', 'machines'])).default(['none']),
  goal: z.enum(['generalFitness', 'strength', 'conditioning']),
  difficulty: z.enum(['easy', 'medium', 'hard']),
  constraints: z.array(z.string()).optional(),
  preferences: z.array(z.string()).optional()
});

// Prompt + schema hint
function buildPrompt(payload) {
  const schemaHint = {
    type: 'object',
    required: ['plan', 'explanation'],
    properties: {
      plan: {
        type: 'object',
        required: ['id', 'name', 'goal', 'weeks', 'sessions'],
        properties: {
          id: { type: 'string' },
          name: { type: 'string' },
          goal: { type: 'string', enum: ['generalFitness', 'strength', 'conditioning'] },
          weeks: { type: 'integer', minimum: 1, maximum: 12 },
          sessions: {
            type: 'array',
            minItems: 1,
            items: {
              type: 'object',
              required: ['id', 'title', 'estimatedDurationSeconds', 'difficulty', 'exercises'],
              properties: {
                id: { type: 'string' },
                title: { type: 'string' },
                estimatedDurationSeconds: { type: 'integer', minimum: 0, maximum: 10800 },
                difficulty: { type: 'string', enum: ['easy', 'medium', 'hard'] },
                exercises: {
                  type: 'array',
                  minItems: 3,
                  items: {
                    type: 'object',
                    required: ['name', 'sets', 'repsMin', 'repsMax', 'restSeconds'],
                    properties: {
                      name: { type: 'string' },
                      sets: { type: 'integer', minimum: 1, maximum: 10 },
                      repsMin: { type: 'integer', minimum: 1, maximum: 100 },
                      repsMax: { type: 'integer', minimum: 1, maximum: 100 },
                      restSeconds: { type: 'integer', minimum: 10, maximum: 600 },
                      targetWeightKg: { type: ['number', 'null'] }
                    }
                  }
                }
              }
            }
          }
        }
      },
      explanation: { type: 'string' }
    }
  };

  const system = 'You are a certified strength coach. Return ONLY JSON matching the schema. Respect time budget and available equipment.';
  const user = `Generate a workout plan JSON for these inputs.\nInputs: ${JSON.stringify(payload)}\nSchema: ${JSON.stringify(schemaHint)}\nReturn ONLY JSON.`;
  return { system, user };
}

// Gemini client
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

app.post('/generate', async (req, res) => {
  const parse = GenerateSchema.safeParse(req.body);
  if (!parse.success) {
    return res.status(400).json({ error: 'invalid_request', details: parse.error.flatten() });
  }
  const payload = parse.data;
  const { system, user } = buildPrompt(payload);

  try {
    const model = genAI.getGenerativeModel({
      model: MODEL_ID,
      systemInstruction: system,
      generationConfig: { responseMimeType: 'application/json', temperature: 0.6 }
    });
    const result = await model.generateContent(user);
    const text = result.response.text();
    const json = JSON.parse(text);
    return res.json(json);
  } catch (err) {
    console.error('AI error:', err?.message || err);
    return res.status(500).json({ error: 'ai_error', message: 'Failed to generate plan' });
  }
});

app.get('/health', (req, res) => {
  return res.json({ ok: true, model: MODEL_ID });
});

app.listen(PORT, () => {
  console.log(`AI backend listening on http://0.0.0.0:${PORT}`);
});


