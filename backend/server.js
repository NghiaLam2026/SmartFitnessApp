import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import NewsAPI from 'newsapi';
import { generateWorkout } from './services/workoutGenerator.js';

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

// NewsAPI key is optional - feature will work but won't fetch fresh articles
if (!process.env.NEWS_API_KEY) {
  console.warn('WARNING: NEWS_API_KEY is not set. News feed feature will use cached articles only.');
  console.warn('To enable NewsAPI, add NEWS_API_KEY=your_newsapi_key to backend/.env');
}

console.log('Environment variables loaded successfully');
console.log('GEMINI_API_KEY is set (length:', process.env.GEMINI_API_KEY.length, 'characters)');
if (process.env.NEWS_API_KEY) {
  console.log('NEWS_API_KEY is set (length:', process.env.NEWS_API_KEY.length, 'characters)');
}

// Initialize NewsAPI client
const newsapi = process.env.NEWS_API_KEY 
  ? new NewsAPI(process.env.NEWS_API_KEY)
  : null;

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

// Fetch news articles from NewsAPI
app.get('/fetch-news', async (req, res) => {
  try {
    const { topic, topicLabel } = req.query;

    if (!topic || typeof topic !== 'string' || topic.trim().length === 0) {
      return res.status(400).json({
        error: 'Missing or invalid "topic" query parameter',
        message: 'Topic must be a non-empty string',
      });
    }

    if (!newsapi) {
      return res.status(503).json({
        error: 'NewsAPI key not configured',
        message: 'Please configure NEWS_API_KEY in backend/.env',
      });
    }

    // Fetch from NewsAPI using the official client
    const response = await newsapi.v2.everything({
      q: topic.trim(),
      language: 'en',
      sortBy: 'publishedAt',
      pageSize: 20, // Fetch more to filter accurately
    });

    if (response.status !== 'ok') {
      console.error('NewsAPI error:', response);
      return res.status(500).json({
        error: 'Failed to fetch news from NewsAPI',
        message: response.message || 'Unknown error',
      });
    }

    // Topic-specific keyword filters for accurate filtering
    const topicKeywords = {
      'fitness': ['fitness', 'exercise', 'workout', 'training', 'cardio', 'aerobics', 'physical activity', 'gym', 'exercise routine', 'workout plan'],
      'nutrition': ['nutrition', 'diet', 'healthy eating', 'meal', 'food', 'calorie', 'protein', 'vitamin', 'nutrient', 'nutritional', 'eating plan', 'meal prep'],
      'weight loss': ['weight loss', 'fat loss', 'lose weight', 'slimming', 'weight management', 'calorie deficit', 'weight reduction', 'burn calories'],
      'muscle building': ['muscle', 'strength training', 'hypertrophy', 'bodybuilding', 'muscle growth', 'gains', 'lifting', 'resistance training', 'muscle mass']
    };

    // Get keywords for the current topic (default to fitness if unknown)
    const label = (topicLabel || 'fitness').toLowerCase();
    const keywords = topicKeywords[label] || topicKeywords['fitness'];
    
    // Filter articles to match the specific topic
    const filteredArticles = (response.articles || []).filter(article => {
      const title = (article.title || '').toLowerCase();
      const description = (article.description || '').toLowerCase();
      const content = `${title} ${description}`;
      // Article must contain at least one topic-specific keyword
      return keywords.some(keyword => content.includes(keyword));
    });

    // Return top 5 filtered articles
    const articlesToReturn = filteredArticles.slice(0, 5);

    res.json({
      articles: articlesToReturn,
      totalResults: filteredArticles.length,
    });
  } catch (error) {
    console.error('Error fetching news:', error);
    res.status(500).json({
      error: 'Failed to fetch news',
      message: error.message,
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 AI Workout Generator API running on port ${PORT}`);
  console.log(`📝 Health check: http://localhost:${PORT}/health`);
});

