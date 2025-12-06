# Context Directory

This directory contains comprehensive documentation for the Smart Fitness App's push notification system implementation.

## Files

### 1. `PUSH_NOTIFICATION_COMPLETE_HISTORY.md`
**The Master Document** - Complete implementation history from start to finish.

**Contents:**
- Initial requirements and technology stack
- Complete database schema with all tables
- All Supabase functions (set_daily_motivation_time, send_daily_motivation_via_fcm, etc.)
- Flutter implementation details (NotificationService, background processor)
- Complete notification flows for all types (daily motivation, welcome, milestones)
- All major issues encountered and their solutions (10+ issues documented)
- Architecture decisions and rationale
- Testing & debugging techniques
- Current working state and limitations
- Performance considerations and future enhancements
- Final architecture diagram

**Use this when:** You need complete context about how the notification system was built, what problems were solved, and why certain decisions were made.

---

### 2. `NOTIFICATION_FLOW_COMPLETE.md`
**Technical Flow Documentation** - How notifications actually work.

**Contents:**
- Step-by-step flow for each notification type
- Database function details
- Flutter background processor code
- Database schema reference
- Testing instructions
- Troubleshooting guide

**Use this when:** You need to understand how a notification flows through the system, or you're debugging why a notification isn't working.

---

### 3. `DAILY_MOTIVATION_SETUP.md`
**Setup & Testing Guide** - Quick reference for daily motivation notifications.

**Contents:**
- How daily motivation works (simplified)
- Quick test instructions (2-5 minutes)
- Database verification queries
- Troubleshooting checklist

**Use this when:** You need to quickly test or verify that daily motivation notifications are working.

---

## Quick Reference

### For New Developers
Start with: `PUSH_NOTIFICATION_COMPLETE_HISTORY.md`
- Read sections 1-5 for context
- Jump to "Complete Notification Flow" to understand the system
- Reference "Major Issues" section to avoid common pitfalls

### For Debugging
Start with: `NOTIFICATION_FLOW_COMPLETE.md`
- Check the flow diagram for your notification type
- Use the troubleshooting section
- Run the database queries to verify state

### For Testing
Start with: `DAILY_MOTIVATION_SETUP.md`
- Follow the "Quick Test" instructions
- Use verification queries to check database state

---

## Key Concepts

### Architecture Overview
```
User Device (Flutter App)
    ↓
Background Processor (every 60s)
    ↓
Queries notification_jobs table
    ↓
Calls quick-api Edge Function
    ↓
Firebase Cloud Messaging
    ↓
Notification delivered to device
```

### Three Notification Types
1. **Daily Motivation** - Scheduled via pg_cron, processed by Flutter app
2. **Welcome** - Triggered on new FCM token, processed by Flutter app
3. **Milestones** - Direct Edge Function call, immediate delivery

### Critical Components
- **Database:** PostgreSQL with pg_cron extension
- **Edge Function:** `quick-api` (Deno/TypeScript)
- **Flutter Service:** `NotificationService` singleton
- **Firebase:** FCM for push delivery

---

## Common Issues & Quick Fixes

### "Notification not received"
1. Check FCM token exists: `SELECT * FROM user_notification_tokens WHERE user_id = 'YOUR_ID';`
2. Check pending jobs: `SELECT * FROM notification_jobs WHERE status = 'pending';`
3. Verify app is running (background processor requires app alive)
4. Check Edge Function logs in Supabase Dashboard

### "Jobs stuck as pending"
- App must be running for background processor to work
- Check Flutter logs for: `"NotificationService: Checking for pending notification jobs..."`

### "Wrong time / timezone issues"
- System uses Eastern Time (`America/New_York`) hardcoded
- Database stores UTC, converts to ET for comparisons
- Flutter app uses `.toUtc()` for all time queries

---

## Related Files in Codebase

### Flutter
- `lib/services/notification_service.dart` - Core notification logic
- `lib/features/profile/presentation/notification_settings_page.dart` - UI for settings
- `lib/main.dart` - Initialization

### Backend
- `supabase/functions/quick-api/index.ts` - Edge Function for FCM
- `supabase/migrations/20250121_notifications_complete.sql` - Database setup
- `supabase/migrations/20250126_daily_motivation_fcm.sql` - Daily motivation setup

### Configuration
- `android/app/src/main/AndroidManifest.xml` - Android permissions
- `pubspec.yaml` - Flutter dependencies
- `.env` - Supabase credentials

---

## Status

**Current State:** ✅ Production Ready
**Last Updated:** November 29, 2025
**All Notification Types:** Working
**Known Limitations:** 
- App must be running for notifications to send
- Hardcoded to Eastern Time
- No web support

---

## Next Steps

If you're implementing unit tests (as planned), refer to:
- `PUSH_NOTIFICATION_COMPLETE_HISTORY.md` - Section "Flutter Implementation" for methods to test
- Create test mocks for: SupabaseClient, FirebaseMessaging, SharedPreferences
- Test key methods: `scheduleDailyMotivation()`, `_processBackgroundNotificationJobs()`, `_sendWelcomeNotification()`

---

*This directory serves as the single source of truth for the push notification system implementation.*

