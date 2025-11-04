# Smart Fitness AI Workout Generator Backend

[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-4.x-000000?logo=express&logoColor=white)](https://expressjs.com)
[![Google Gemini](https://img.shields.io/badge/Google_Gemini-2.5_Flash-4285F4?logo=google&logoColor=white)](https://ai.google.dev)

Backend API service for generating AI-powered workout plans using Google Gemini.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [API Endpoints](#api-endpoints)
- [Environment Variables](#environment-variables)
- [Development](#development)
- [Error Handling](#error-handling)
- [Troubleshooting](#troubleshooting)

## Overview

This backend service provides a RESTful API for generating personalized workout plans using Google's Gemini AI. It accepts user workout preferences and available exercises, then generates 3 unique, tailored workout plans.

### Key Features

- **AI-Powered Generation**: Uses Google Gemini 2.5 Flash for intelligent workout plan creation
- **Robust JSON Parsing**: Handles markdown code blocks and malformed JSON responses
- **Input Validation**: Validates exercises against available database
- **Error Recovery**: Comprehensive error handling and logging

## Prerequisites

- **Node.js** 18.x or higher
- **npm** (comes with Node.js)
- **Google Gemini API Key** - [Get API key](https://makersuite.google.com/app/apikey)

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Create a `.env` file in the `backend/` directory:

```bash
cp .env.example .env  # If .env.example exists
```

Edit `.env` and add your configuration:

```env
GEMINI_API_KEY=your_gemini_api_key_here
PORT=3000
```

**⚠️ Important:** Never commit your `.env` file. It's already in `.gitignore`.

### 3. Start the Server

```bash
# Development mode (with auto-reload using nodemon)
npm run dev

# Production mode
npm start
```

The server will start on `http://localhost:3000` by default.

### 4. Verify Installation

Test the health check endpoint:

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "ok",
  "message": "AI Workout Generator API is running"
}
```

## API Endpoints

### `POST /generate-workout`

Generates 3 personalized workout plans based on user specifications.

**Request Body:**

```json
{
  "message": "Upper body strength workout, 45 minutes, beginner level",
  "exercises": [
    {
      "id": "exercise-uuid",
      "name": "Push Up",
      "muscle": "chest",
      "equipment": "none"
    }
  ]
}
```

**Request Fields:**
- `message` (string, required): User's workout preferences and requirements
- `exercises` (array, required): List of available exercises from the database

**Response:**

```json
{
  "message": "Successfully generated 3 personalized workout plans",
  "workouts": [
    {
      "title": "Workout Title",
      "description": "Workout description",
      "exercises": [
        {
          "exerciseId": "exercise-uuid",
          "exerciseName": "Exercise Name",
          "orderIndex": 0,
          "restSeconds": 60,
          "sets": [
            {"reps": 10, "weight": null}
          ]
        }
      ]
    }
  ]
}
```

**Response Fields:**
- `message` (string): Status message
- `workouts` (array): Array of 3 workout plans, each containing:
  - `title` (string): Workout name
  - `description` (string): Brief description
  - `exercises` (array): List of exercises with sets, reps, and rest periods
  - **Note:** Weights are always `null` - users enter weights manually after workout creation

**Status Codes:**
- `200`: Success
- `400`: Bad Request (missing/invalid parameters)
- `500`: Internal Server Error

### `GET /health`

Health check endpoint to verify the server is running.

**Response:**

```json
{
  "status": "ok",
  "message": "AI Workout Generator API is running"
}
```

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `GEMINI_API_KEY` | Your Google Gemini API key | Yes | - |
| `PORT` | Server port number | No | `3000` |

## Development

### Project Structure

```
backend/
├── services/
│   └── workoutGenerator.js  # AI workout generation logic
├── server.js                # Express server setup
├── package.json             # Dependencies and scripts
└── .env                     # Environment variables (gitignored)
```

### Key Implementation Details

1. **JSON Parsing**: The service uses a robust brace-counting algorithm to extract JSON from AI responses, even when wrapped in markdown code blocks.

2. **Exercise Validation**: Generated exercises are validated against the provided exercise list to ensure only valid exercises are included.

3. **Weight Handling**: All weights are set to `null` - users manually enter weights when editing workouts.

4. **Error Handling**: Comprehensive error logging helps debug issues during development.

## Error Handling

The API returns appropriate HTTP status codes:

- `200`: Success
- `400`: Bad Request (missing/invalid parameters)
- `500`: Internal Server Error

### Common Error Scenarios

1. **Invalid API Key**: Server will exit on startup if `GEMINI_API_KEY` is not set
2. **JSON Parse Errors**: Detailed error messages with problematic sections are logged
3. **Missing Exercises**: Warnings are logged for exercises not found in the database

## Troubleshooting

### Server won't start

**Issue:** `GEMINI_API_KEY is not set`

**Solution:** Ensure `.env` file exists in the `backend/` directory and contains `GEMINI_API_KEY=your_key`

### API returns 500 errors

**Issue:** JSON parsing errors

**Solution:** 
- Check backend logs for detailed error messages
- Verify the Gemini API is accessible
- Check that the API key is valid

### Flutter app can't connect to backend

**Issue:** Connection refused or timeout

**Solution:**
- Ensure backend is running: `npm run dev`
- For Android emulator: Backend URL should be `http://10.0.2.2:3000` (automatic)
- For iOS simulator: Backend URL should be `http://localhost:3000` (automatic)
- For physical device: Use your computer's IP address (e.g., `http://192.168.1.100:3000`)

### Generated workouts have incorrect exercises

**Issue:** AI includes exercises not in the database

**Solution:** The service automatically filters out invalid exercises. Check logs for warnings about skipped exercises.

---

**Note:** For production deployment, ensure:
- Environment variables are properly configured
- CORS is configured for your frontend domain
- API keys are stored securely
- Server is running on HTTPS (recommended)
