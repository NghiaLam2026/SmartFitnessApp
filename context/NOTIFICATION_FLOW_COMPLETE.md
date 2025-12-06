# Complete Notification System Flow

## Overview

The notification system works in 3 stages:

1. **Job Creation** (Database/Cron or App)
2. **Job Detection** (Flutter Background Processor)
3. **FCM Delivery** (Edge Function)

---

## Daily Motivation Notifications

### Flow:

1. **User sets time** → `Profile → Notification Settings`
   - User selects e.g., 10:55 AM

2. **App saves to database** → Calls `set_daily_motivation_time()` RPC
   - Stores in `notification_prefs` table
   - Time saved as TIME type (10:55:00)

3. **pg_cron job runs every minute** 
   - Calls `send_daily_motivation_via_fcm()`
   - Checks current Eastern Time
   - If matches user's time, creates a `notification_jobs` entry with `status: 'pending'`

4. **Flutter app's background processor** (runs every 60 seconds)
   - Queries for `status = 'pending'` jobs
   - For each job, calls `quick-api` Edge Function with job payload
   - Updates job status to `'completed'`

5. **Edge Function sends FCM**
   - Receives notification details
   - Sends push notification to user's FCM token

### Database Functions:

- `set_daily_motivation_time(p_user_id, p_hour, p_minute)` - Saves user's preferred time
- `send_daily_motivation_via_fcm()` - Called by cron every minute, creates pending jobs

---

## Welcome Notifications

### Flow:

1. **User logs in**
   - App gets FCM token
   - Checks if token is new (not already in `user_notification_tokens`)

2. **New token detected**
   - App calls `send_welcome_notification()` RPC function
   - Creates a `notification_jobs` entry with `status: 'pending'`

3. **Background processor picks it up**
   - Next 60-second cycle, finds the pending welcome job
   - Calls `quick-api` Edge Function

4. **FCM delivers welcome message**

### Database Functions:

- `send_welcome_notification(p_user_id)` - Creates pending notification job

---

## Workout Milestone Notifications

### Flow:

1. **User creates/completes a workout**
   - App calls workout creation endpoint
   - Checks if it's a milestone (1st, 3rd, 5th, 10th, etc.)

2. **Milestone detected**
   - App directly calls `quick-api` Edge Function with achievement payload
   - (Skips the database job queue for immediate delivery)

---

## Flutter App Background Processor

### Location: `lib/services/notification_service.dart`

### What it does:

1. Initializes when app starts
2. Runs a timer every 60 seconds
3. Queries `notification_jobs` table for pending jobs
4. For each job:
   - Calls `quick-api` Edge Function
   - Updates job status to `'completed'`

### Key Code:

```dart
void _startBackgroundJobProcessor() {
  _backgroundJobTimer = Timer.periodic(const Duration(seconds: 60), (_) {
    _processBackgroundNotificationJobs();
  });
}

Future<void> _processBackgroundNotificationJobs() async {
  // Query pending jobs
  final pendingJobs = await supabase
      .from('notification_jobs')
      .select('id, user_id, kind, payload')
      .eq('status', 'pending')
      .lte('run_at', DateTime.now().toIso8601String());
  
  // Process each job by calling Edge Function
  for (final job in pendingJobs) {
    await supabase.functions.invoke('quick-api', body: {
      'user_id': job['user_id'],
      'kind': job['kind'],
      'payload': job['payload'],
    });
    
    // Mark as completed
    await supabase
        .from('notification_jobs')
        .update({'status': 'completed'})
        .eq('id', job['id']);
  }
}
```

---

## Constraints & Settings

### Timezone
- **Set to:** `America/New_York` (Eastern Time)
- **Used in:** `send_daily_motivation_via_fcm()` function
- **Why:** All time comparisons are against ET

### notification_jobs table schema

```sql
- id (UUID)
- user_id (UUID) → references auth.users
- kind (TEXT) - event_notification, achievement, etc.
- run_at (TIMESTAMP) - when the job should run
- payload (JSONB) - title, body, route, etc.
- status (TEXT) - pending, processing, completed, failed, canceled
- last_error (TEXT) - error message if failed
- processed_at (TIMESTAMP) - when it was processed
```

### notification_prefs table schema

```sql
- id (UUID)
- user_id (UUID) → references auth.users
- kind (TEXT) - reminder
- enabled (BOOLEAN)
- inactivity_hours (INTEGER)
- daily_motivation_time (TIME) - e.g., 10:55:00
- time_zone (TEXT) - e.g., America/New_York
```

---

## Testing

### Quick Test (Daily Motivation)

1. Open app and log in
2. Go to `Profile → Notification Settings`
3. Set reminder to **current Eastern Time + 2 minutes**
4. Keep app in background
5. Wait ~2-3 minutes
6. Check logs for: `"NotificationService: Found X pending jobs"`
7. Notification should arrive

### Check Logs

```
I/flutter: NotificationService: Checking for pending notification jobs...
I/flutter: NotificationService: Found 1 pending jobs
I/flutter: NotificationService: Completed notification job [id]
```

---

## Troubleshooting

### No pending jobs found
- Check if `notification_prefs` has the reminder entry
- Verify current Eastern Time matches scheduled time
- Check if cron job is running: `SELECT * FROM cron.job WHERE jobname = 'daily-fitness-motivation';`

### Jobs stuck as 'pending'
- Check if app is running (background processor only works while app is alive)
- Check FCM token exists: `SELECT * FROM user_notification_tokens WHERE user_id = 'your-id';`
- Check Edge Function logs

### Wrong timezone
- Verify `send_daily_motivation_via_fcm()` uses `'America/New_York'`
- Verify user's saved time matches their Eastern Time

