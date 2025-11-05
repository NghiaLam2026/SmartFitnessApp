# Smart Fitness App

[![Flutter](https://img.shields.io/badge/Flutter-3.x+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-21EC37?logo=supabase&logoColor=white)](https://supabase.com)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?logo=node.js&logoColor=white)](https://nodejs.org)

⭐ **A personalized AI-powered fitness companion** that adapts to your unique needs, goals, and habits.

## Table of Contents

- [About](#-about)
- [Key Features](#-key-features)
- [Tech Stack](#-tech-stack)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Environment Setup](#environment-setup)
  - [Running the App](#running-the-app)
- [Project Structure](#-project-structure)
- [AI Workout Generator](#-ai-workout-generator)
- [Contributing](#-contributing)
- [Team](#-team)

## 🚀 About

The **Smart Fitness App** is a personalized health and fitness companion that helps users improve their wellness through **AI-driven workout and nutrition planning**, real-time progress tracking, and data-driven insights.

Unlike generic fitness apps, our solution adapts dynamically to each user's unique needs, goals, and habits, providing a **tailored experience** that bridges the gap between basic workout guides and expensive personal trainers.

This app is designed to support a wide range of users:
- **Beginners** seeking structured guidance
- **Busy professionals** looking for time-efficient, effective workouts
- **Health-conscious individuals** who need ongoing motivation and habit tracking
- **Fitness enthusiasts** who want a more advanced, data-driven approach

By combining **AI personalization** and **real-time analytics**, the Smart Fitness App aims to solve the most common challenges in fitness:
- Lack of **consistency** and **motivation**
- Limited **accessibility** to personal training
- Difficulty in **tracking progress and adapting plans** effectively

## ✨ Key Features

- **🎯 Personalized AI Plans**: Adaptive workout and nutrition recommendations based on user goals, lifestyle, and data
- **🤖 AI Coach (RAG-Powered)**: Conversational assistant using a vector database and embeddings to deliver **context-aware, tailored advice**
- **📊 Progress Tracking & Analytics**: Monitor performance trends with clear, visual insights
- **🏃 Community Event Tracker**: Discover local fitness activities such as CrossFit competitions, marathons, and 5Ks by searching nearby events using the user's ZIP code
- **💰 Affordable & Accessible**: More cost-effective than personal trainers, but more adaptive than generic fitness apps

## 🛠 Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter (Dart) |
| **Backend** | Node.js/Express |
| **Database** | Supabase (PostgreSQL + pgvector) |
| **Authentication** | Supabase Auth |
| **AI Layer** | Google Gemini 2.5 Flash |
| **State Management** | Riverpod |
| **Routing** | GoRouter |

## 📦 Getting Started

### Prerequisites

- **Flutter SDK** (3.x or higher) - [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (3.x or higher) - Comes with Flutter
- **Node.js** (18.x or higher) - [Install Node.js](https://nodejs.org/)
- **Supabase Account** - [Sign up for free](https://supabase.com)
- **Google Gemini API Key** - [Get API key](https://makersuite.google.com/app/apikey)

### Environment Setup

1. **Clone the repository:**
```bash
git clone <repository-url>
cd smart_fitness_app
```

2. **Set up Flutter environment:**

Create a `.env` file at the project root (or use build-time defines):

```bash
# .env file
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

3. **Set up Backend environment:**

Navigate to the backend directory and create a `.env` file:

```bash
cd backend
cp .env.example .env  # If .env.example exists
```

Edit `.env` and add:
```
GEMINI_API_KEY=your_gemini_api_key_here
PORT=3000
```

4. **Install dependencies:**

```bash
# Flutter dependencies
flutter pub get

# Backend dependencies
cd backend
npm install
```

### Running the App

1. **Start the backend server:**
```bash
cd backend
npm run dev  # Development mode with auto-reload
# or
npm start   # Production mode
```

The backend will run on `http://localhost:3000` by default.

2. **Run the Flutter app:**
```bash
# From project root
flutter run
```

**Note:** For Android emulators, the app automatically uses `http://10.0.2.2:3000` to access the host machine's localhost. For iOS simulators, it uses `http://localhost:3000`. For physical devices, you'll need to use your computer's IP address (e.g., `http://192.168.1.100:3000`).

## 📁 Project Structure

```
smart_fitness_app/
├── lib/
│   ├── app/              # App configuration, routing, theme
│   ├── core/             # Constants, utilities, widgets
│   └── features/         # Feature modules
│       ├── auth/         # Authentication
│       ├── workouts/     # Workout management & AI generator
│       ├── exercises/    # Exercise database
│       ├── recipes/      # Nutrition & recipes
│       ├── tracking/     # Progress tracking
│       ├── injury/       # Injury prevention
│       ├── home/         # Home dashboard
│       └── profile/      # User profile
├── backend/              # Node.js/Express API server
│   ├── services/         # AI workout generation service
│   └── server.js        # Express server setup
├── android/             # Android-specific files
├── ios/                 # iOS-specific files
└── pubspec.yaml         # Flutter dependencies
```

## 🤖 AI Workout Generator

The app includes an AI-powered workout generator that creates personalized workout plans based on user specifications.

### How it works:

1. User enters workout preferences (e.g., "Upper body strength, 45 minutes, beginner")
2. App sends request to backend with available exercises
3. Backend uses Google Gemini AI to generate 3 unique workout plans
4. User can preview and select workouts to add to their plan
5. Users manually enter weights for each exercise (no AI weight suggestions)

For more details, see [Backend README](backend/README.md).

### Backend API:

- **Health Check**: `GET /health`
- **Generate Workouts**: `POST /generate-workout`

## 🌐 Contributing

Choose the path that matches your access level.

### Team members (have write access) – clone
```bash
git clone <repo-url>
cd smart_fitness_app

# Create a feature branch
git checkout -b feature/my-change

# Work, then commit
git add -A
git commit -m "feat: my change"

# First push: set upstream tracking so future pushes are simple
git push -u origin feature/my-change
```

If you forget `-u` or see an error like “no upstream branch”, set it:
```bash
git push --set-upstream origin feature/my-change
```

After your branch tracks the remote, you can use:
```bash
git push   # pushes to origin/feature/my-change
git pull   # pulls from origin/feature/my-change
```

### Final step: Open a Pull Request
- Go to your repository on GitHub
- Click "Compare & pull request" for `feature/my-change` → `main`
- Add a clear title/description (link the related issue if any)
- Request reviewers and submit the PR


## 👥 Team

| Name | Role |
|------|------|
| Jalen Presha | TBD |
| Nghia Lam | TBD |
| Harshith Boopathy | TBD |
| Viviana Veca | TBD |
| Muhammad Alyan Khan | TBD |

---

**Note:** `.env` files are ignored by git. Use `.env.example` files to share variable names with collaborators. Never commit sensitive information like API keys or credentials.
