import { GoogleGenAI } from '@google/genai';
import dotenv from 'dotenv';

dotenv.config()
// Get API key from environment
const apiKey = process.env.GEMINI_API_KEY;

// Validate API key is present
if (!apiKey) {
  console.error('GEMINI_API_KEY is not set in environment variables!');
  console.error('Please make sure you have a .env file with GEMINI_API_KEY=your_key');
  throw new Error('GEMINI_API_KEY environment variable is required');
}

console.log('GEMINI_API_KEY loaded (length:', apiKey.length, 'characters)');

// Initialize with API key - the new SDK uses environment variable or config
const ai = new GoogleGenAI({
  apiKey: apiKey,
});

/**
 * Generates workout plans using Google Gemini AI
 * @param {string} userMessage - User's workout preferences/requirements
 * @param {Array} availableExercises - List of available exercises from database
 * @returns {Promise<Object>} - Generated workout plans
 */
export async function generateWorkout(userMessage, availableExercises) {
  try {
    // Validate API key is still set (double-check)
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY is not set');
    }

    // Format exercises for the prompt
    const exercisesList = availableExercises
      .slice(0, 100) // Limit to 100 exercises to avoid token limits
      .map((ex) => {
        const muscle = ex.muscle || 'full body';
        const equipment = ex.equipment || 'none';
        return `- ${ex.name} (${muscle}, equipment: ${equipment})`;
      })
      .join('\n');

    const systemPrompt = `You are an expert fitness trainer and workout planner. Your task is to generate exactly 3 different, personalized workout plans based on user requests.

Available Exercises:
${exercisesList}

CRITICAL REQUIREMENTS - FOLLOW THESE STRICTLY:
1. Generate EXACTLY 3 workout plans (no more, no less)
2. Each workout must be unique with different exercise selections, rep ranges, and structures
3. Use ONLY exercises from the provided list above - DO NOT invent or modify exercise names
4. Match exercises to user's goals, fitness level, and preferences
5. Each workout MUST have 4-8 exercises (minimum 4, maximum 8)
6. Provide appropriate rep ranges (8-15 for strength, 15-20 for endurance)
7. Include rest periods between sets (30-180 seconds)
8. DO NOT include weights in the generated workouts:
   - Always set weight to null for all exercises
   - Users will enter their own weights manually after the workout is created
   - Example: {"reps": 12, "weight": null}

WORKOUT TITLE AND EXERCISE SELECTION VALIDATION:
- The workout title MUST accurately reflect the exercises you select
- "Full Body" workouts MUST include exercises targeting multiple muscle groups (upper body, lower body, core)
- "Upper Body" workouts MUST only include chest, back, shoulders, arms exercises
- "Lower Body" workouts MUST only include legs, glutes exercises
- "Core" workouts MUST focus on abdominal and core exercises
- Each workout should have VARIETY - don't use the same exercise multiple times
- For "Full Body": include at least one exercise from 3+ different muscle groups (chest, back, legs, shoulders, core)
- Exercise selection MUST match the workout's stated focus in the title and description

EXERCISE VARIETY REQUIREMENTS:
- Do NOT repeat the same exercise multiple times in one workout
- Each exercise should target a different muscle group or movement pattern
- Ensure proper workout balance (e.g., if including push exercises, include pull exercises too)

You MUST respond with valid JSON only, in this exact format:
{
  "workouts": [
    {
      "title": "Workout Title 1",
      "description": "Brief description that accurately describes the exercises included",
      "exercises": [
        {
          "exerciseId": "exact_exercise_id_from_list",
          "exerciseName": "Exact Exercise Name from list",
          "orderIndex": 0,
          "restSeconds": 60,
          "sets": [
            {"reps": 10, "weight": null}
          ]
        }
      ]
    },
    {
      "title": "Workout Title 2",
      "description": "Brief description",
      "exercises": [...]
    },
    {
      "title": "Workout Title 3",
      "description": "Brief description",
      "exercises": [...]
    }
  ]
}

CRITICAL VALIDATION BEFORE RESPONDING:
1. Verify each exerciseId and exerciseName matches EXACTLY from the provided list
2. Verify the workout title matches the muscle groups targeted by the exercises
3. Verify "Full Body" workouts have exercises from multiple muscle groups
4. Verify no exercise is repeated in the same workout
5. Verify each workout has 4-8 exercises
6. Verify exercise variety (different muscle groups/movement patterns)

CRITICAL JSON FORMAT REQUIREMENTS:
- Respond with ONLY the JSON object, no markdown code blocks
- Do not include any text, explanations, or comments before or after the JSON
- Start your response directly with the opening brace
- End your response directly with the closing brace
- Ensure the JSON is valid and parseable
- Double-check all quotes are properly escaped
- Verify all braces and brackets are properly matched

IMPORTANT:
- exerciseId and exerciseName must match EXACTLY from the provided exercise list
- Each workout should offer variety (different focus areas, intensities, or approaches)
- Make sure all 3 workouts are distinct and valuable options
- Double-check that workout titles accurately represent the exercises selected`;

    const fullPrompt = `${systemPrompt}\n\nUser Request: ${userMessage}`;

    // Use the new SDK API structure
    console.log('Calling Gemini API with model: gemini-2.5-flash');
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: fullPrompt,
    });
    
    // Extract text from the new SDK response structure
    let rawText = '';
    if (response.candidates && response.candidates.length > 0) {
      const candidate = response.candidates[0];
      if (candidate.content && candidate.content.parts) {
        // Extract text from parts array
        rawText = candidate.content.parts
          .map(part => part.text || '')
          .join('');
      } else if (candidate.text) {
        rawText = candidate.text;
      }
    } else if (response.text) {
      rawText = response.text;
    }
    
    if (!rawText || rawText.trim().length === 0) {
      console.error('No text found in response:', JSON.stringify(response, null, 2));
      throw new Error('No text content in AI response');
    }
    
    console.log('Extracted text length:', rawText.length);
    console.log('First 200 chars:', rawText.substring(0, 200));

    // Parse the JSON response with robust extraction
    let workoutsData;
    try {
      // Step 1: Remove all markdown code blocks comprehensively
      let cleanedText = rawText.trim();
      
      // Remove markdown code blocks - handle multiple patterns
      // Pattern 1: ```json ... ```
      cleanedText = cleanedText.replace(/```json\s*\n?/gi, '');
      cleanedText = cleanedText.replace(/```\s*\n?/g, '');
      // Remove any remaining backticks
      cleanedText = cleanedText.replace(/```/g, '');
      
      // Step 2: Find the JSON object (starts with { and ends with })
      // Use a more robust regex that handles nested braces
      let jsonStart = cleanedText.indexOf('{');
      if (jsonStart === -1) {
        throw new Error('No JSON object found in response (missing opening brace)');
      }
      
      // Find matching closing brace by counting braces
      let braceCount = 0;
      let jsonEnd = -1;
      for (let i = jsonStart; i < cleanedText.length; i++) {
        if (cleanedText[i] === '{') {
          braceCount++;
        } else if (cleanedText[i] === '}') {
          braceCount--;
          if (braceCount === 0) {
            jsonEnd = i + 1;
            break;
          }
        }
      }
      
      if (jsonEnd === -1) {
        throw new Error('No valid JSON object found in response (missing closing brace)');
      }
      
      // Extract the JSON string
      let jsonString = cleanedText.substring(jsonStart, jsonEnd).trim();
      
      // Step 3: Clean up common JSON issues
      // Ensure all weights are null
      jsonString = jsonString.replace(/"weight":\s*[^,}\]]+/g, '"weight": null');
      
      // Fix trailing commas before closing braces/brackets
      jsonString = jsonString.replace(/,(\s*[}\]])/g, '$1');
      
      // Step 4: Parse the JSON
      workoutsData = JSON.parse(jsonString);
      
      // Validate structure
      if (!workoutsData || typeof workoutsData !== 'object') {
        throw new Error('Parsed JSON is not an object');
      }
      
    } catch (parseError) {
      console.error('Error parsing Gemini response:', parseError.message);
      console.error('Raw text length:', rawText.length);
      console.error('Raw text (first 500 chars):', rawText.substring(0, 500));
      console.error('Raw text (last 500 chars):', rawText.substring(Math.max(0, rawText.length - 500)));
      
      // Try to find the problematic position
      const errorMatch = parseError.message.match(/position (\d+)/);
      if (errorMatch) {
        const position = parseInt(errorMatch[1]);
        const start = Math.max(0, position - 150);
        const end = Math.min(rawText.length, position + 150);
        console.error('Problematic section:', rawText.substring(start, end));
      }
      
      throw new Error(`Failed to parse AI response: ${parseError.message}. Please try again.`);
    }

    // Validate and structure the response
    if (!workoutsData.workouts || !Array.isArray(workoutsData.workouts)) {
      throw new Error('Invalid response format: missing workouts array');
    }

    if (workoutsData.workouts.length !== 3) {
      console.warn(
        `Expected 3 workouts, got ${workoutsData.workouts.length}. Using first 3.`
      );
      workoutsData.workouts = workoutsData.workouts.slice(0, 3);
    }

    // Validate and clean up each workout
    const validatedWorkouts = workoutsData.workouts.map((workout, index) => {
      if (!workout.title || !workout.exercises) {
        throw new Error(`Workout ${index + 1} is missing required fields`);
      }

      // Validate exercise count
      if (workout.exercises.length < 4) {
        console.warn(`Workout "${workout.title}" has only ${workout.exercises.length} exercises. Minimum is 4.`);
      }
      if (workout.exercises.length > 8) {
        console.warn(`Workout "${workout.title}" has ${workout.exercises.length} exercises. Maximum is 8. Truncating.`);
        workout.exercises = workout.exercises.slice(0, 8);
      }

      // Check for exercise variety (no duplicates)
      const exerciseNames = workout.exercises.map(ex => ex.exerciseName?.toLowerCase()).filter(Boolean);
      const uniqueExercises = new Set(exerciseNames);
      if (exerciseNames.length !== uniqueExercises.size) {
        console.warn(`Workout "${workout.title}" has duplicate exercises. Removing duplicates.`);
        // Remove duplicates while preserving order
        const seen = new Set();
        workout.exercises = workout.exercises.filter(ex => {
          const name = ex.exerciseName?.toLowerCase();
          if (seen.has(name)) return false;
          seen.add(name);
          return true;
        });
      }

      // Validate workout title matches exercise selection (basic check)
      const titleLower = workout.title.toLowerCase();
      if (titleLower.includes('full body') || titleLower.includes('full-body')) {
        // Check if exercises target multiple muscle groups
        const muscleGroups = new Set();
        workout.exercises.forEach(ex => {
          const matched = availableExercises.find(e => 
            e.id === ex.exerciseId || e.name.toLowerCase() === ex.exerciseName?.toLowerCase()
          );
          if (matched && matched.muscle) {
            muscleGroups.add(matched.muscle.toLowerCase());
          }
        });
        if (muscleGroups.size < 3) {
          console.warn(`Workout "${workout.title}" claims to be full body but only targets ${muscleGroups.size} muscle groups: ${Array.from(muscleGroups).join(', ')}`);
        }
      }

      // Validate exercises
      const validatedExercises = workout.exercises.map((exercise, exIndex) => {
        // Find matching exercise from available list
        const matchedExercise = availableExercises.find(
          (ex) =>
            ex.id === exercise.exerciseId ||
            ex.name.toLowerCase() === exercise.exerciseName?.toLowerCase()
        );

        if (!matchedExercise) {
          console.warn(
            `Exercise "${exercise.exerciseName}" not found in available exercises. Skipping.`
          );
          return null;
        }

        // Parse sets - weights are always null as users will enter them manually
        const validatedSets = (exercise.sets || []).map((set) => {
          return {
            reps: set.reps || null,
            weight: null, // Always null - users will enter weights manually
          };
        });

        return {
          exerciseId: matchedExercise.id,
          exerciseName: matchedExercise.name,
          orderIndex: exIndex,
          restSeconds: exercise.restSeconds || 60,
          sets: validatedSets,
        };
      }).filter((ex) => ex !== null); // Remove exercises that weren't found

      return {
        title: workout.title,
        description: workout.description || '',
        exercises: validatedExercises,
      };
    });

    return {
      message: 'Successfully generated 3 personalized workout plans',
      workouts: validatedWorkouts,
    };
  } catch (error) {
    console.error('Error in generateWorkout:', error);
    throw error;
  }
}

