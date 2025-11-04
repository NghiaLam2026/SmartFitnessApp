import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Get current file directory for proper .env path resolution
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables from .env file in the backend directory
dotenv.config({ path: join(__dirname, '.env') });

// Verify critical environment variables
if (!process.env.GEMINI_API_KEY) {
  console.error('ERROR: GEMINI_API_KEY is not set!');
  console.error('Please create a .env file in the backend/ directory with:');
  console.error('GEMINI_API_KEY=your_gemini_api_key_here');
  process.exit(1);
}

console.log('Environment variables loaded successfully');
console.log('GEMINI_API_KEY is set (length:', process.env.GEMINI_API_KEY.length, 'characters)');

import { generateWorkout } from './services/workoutGenerator.js';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'AI Workout Generator API is running' });
});

// Generate workout endpoint
app.post('/generate-workout', async (req, res) => {
  try {
    const { message, exercises } = req.body;

    if (!message || typeof message !== 'string') {
      return res.status(400).json({
        error: 'Missing or invalid "message" field in request body',
      });
    }

    if (!exercises || !Array.isArray(exercises)) {
      return res.status(400).json({
        error: 'Missing or invalid "exercises" field in request body',
      });
    }

    // Generate workouts using Gemini
    const result = await generateWorkout(message, exercises);

    res.json({
      message: result.message || 'Generated workout plans successfully',
      workouts: result.workouts,
    });
  } catch (error) {
    console.error('Error generating workout:', error);
    res.status(500).json({
      error: 'Failed to generate workout',
      message: error.message,
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 AI Workout Generator API running on port ${PORT}`);
  console.log(`📝 Health check: http://localhost:${PORT}/health`);
});

