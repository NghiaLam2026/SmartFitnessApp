# Smart Fitness App

## Overview
The **Smart Fitness App** is a personalized health and fitness companion that helps users improve their wellness through **AI-driven workout and nutrition planning**, real-time progress tracking, and data-driven insights.  

Unlike generic fitness apps, our solution adapts dynamically to each user’s unique needs, goals, and habits, providing a **tailored experience** that bridges the gap between basic workout guides and expensive personal trainers.

This app is designed to support a wide range of users:
- **Beginners** seeking structured guidance.
- **Busy professionals** looking for time-efficient, effective workouts.
- **Health-conscious individuals** who need ongoing motivation and habit tracking.
- **Fitness enthusiasts** who want a more advanced, data-driven approach.

By combining **AI personalization** and **real-time analytics**, the Smart Fitness App aims to solve the most common challenges in fitness:
- Lack of **consistency** and **motivation**.
- Limited **accessibility** to personal training.
- Difficulty in **tracking progress and adapting plans** effectively.

---

## Key Features
- **Personalized AI Plans**: Adaptive workout and nutrition recommendations based on user goals, lifestyle, and data.
- **AI Coach (RAG-Powered)**: Conversational assistant using a vector database and embeddings to deliver **context-aware, tailored advice**.
- **Progress Tracking & Analytics**: Monitor performance trends with clear, visual insights.
- **Community Event Tracker**: Discover local fitness activities such as CrossFit competitions, marathons, and 5Ks by searching nearby events using the user’s ZIP code, making it easy to connect with others and stay motivated through community engagement.
- **Affordable & Accessible**: More cost-effective than personal trainers, but more adaptive than generic fitness apps.

---

## Tech Stack

The project uses a **modern, scalable, and beginner-friendly stack** to ensure fast development and room for future growth.

| Layer | Technology | Why We Chose It |
|-------|------------|----------------|
| **Frontend** | Flutter (or React Native with Expo) | Single codebase for iOS & Android, great developer tools, strong community. |
| **Backend** | Supabase Edge Functions (initially) + optional Node.js/Express server | Easy to start, can scale later; Express added for custom logic or AI proxy. |
| **Database** | Supabase (Postgres + pgvector) | SQL structure for fitness data + built-in vector search for AI personalization. |
| **Authentication** | Supabase Auth | Secure, simple user login with built-in email/password and OAuth. |
| **AI Layer** | Ollama (local models) → Optional cloud APIs later (OpenAI, Anthropic, etc.) | Start free with local models, upgrade later if needed. |
| **Analytics** | PostHog or Firebase Analytics | Track user behavior and app improvements. |
| **Deployment** | Expo EAS (for RN) or standard Flutter pipeline | Simplified builds and app store releases. |

---

## Team Members
| Name | Role |
|------|------|
| Jalen Presha | TBD |
| Nghia Lam | TBD |
| Harshith Boopathy | TBD |
| Viviana Veca | TBD |
| Muhammad Alyan Khan | TBD |
