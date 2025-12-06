# Daily Motivation FCM Setup

## How It Works

1. **User sets time in app** → App calls `set_daily_motivation_time()` RPC function
2. **Time saved to database** → Stored in `notification_prefs` table
3. **pg_cron job runs every minute** → Checks if any user's scheduled time matches current Eastern Time
4. **Match found** → Creates pending notification job in `notification_jobs` table
5. **Background Job Processor (app)** → Every 60 seconds, app checks for pending jobs
6. **Jobs found** → App calls `quick-api` Edge Function with job details
7. **FCM sent** → Firebase Cloud Messaging delivers notification to user's device

## Database Setup (Already Done ✅)

- ✅ Added `daily_motivation_time` and `time_zone` columns to `notification_prefs`
- ✅ Created `send_daily_motivation_via_fcm()` function
- ✅ Created `set_daily_motivation_time()` RPC function
- ✅ Set up pg_cron job to run every minute: `* * * * *`

## Flutter App Changes (Already Done ✅)

- ✅ Updated `scheduleDailyMotivation()` to call Supabase RPC instead of local notifications
- ✅ Added `SharedPreferences` import
- ✅ Notification Settings page now saves to database
- ✅ Added background job processor that runs every 60 seconds
- ✅ Background job processor checks for pending notifications and calls Edge Function
- ✅ Timezone set to Eastern Time (America/New_York)

## Testing Instructions

### How It Works Now

1. **You set a reminder time** → Saved to database (e.g., 3:30 PM ET)
2. **pg_cron runs every minute** → Checks if current Eastern Time matches any reminder times
3. **Time matches** → Creates a pending notification job
4. **Background job processor in app** → Every 60 seconds, processes pending jobs
5. **Notification sent** → Calls Edge Function → FCM delivers to device

### Quick Test (2-5 minutes)

**Important: The app must be running (foreground or background) for the background job processor to work!**

1. **Open the app and log in**
2. **Go to Profile → Notification Settings**
3. **Set reminder to current Eastern Time + 2 minutes**
   - Example: If it's 3:30 PM ET now, set to 3:32 PM ET
4. **Keep app in background** (minimize but don't close)
5. **Watch Android logs** for confirmation
6. **Wait 2-3 minutes**
7. **Notification should arrive!** 🎉

### Why wait 2-3 minutes?
- pg_cron checks every minute (at :00, :01, :02, etc.)
- Background processor checks every 60 seconds
- So maximum delay is ~2 minutes from scheduled time

### Example
- Current time: **3:28 PM ET**
- Set reminder for: **3:30 PM ET**
- At 3:30 PM (when cron runs), job is created
- At 3:31 PM (when background processor runs), FCM is sent
- At 3:31-3:32 PM, notification arrives ✅

## Verification

**Check if your preference was saved:**

```sql
-- In Supabase SQL Editor
SELECT user_id, kind, daily_motivation_time, enabled 
FROM notification_prefs 
WHERE kind = 'reminder' 
ORDER BY created_at DESC LIMIT 5;
```

**Check cron job status:**

```sql
SELECT * FROM cron.job WHERE jobname = 'daily-fitness-motivation';
```

**Check pending notification jobs:**

```sql
SELECT id, user_id, kind, status, run_at, created_at 
FROM notification_jobs 
WHERE status IN ('pending', 'processing') 
ORDER BY run_at DESC LIMIT 10;
```

## Troubleshooting

**No notification received?**

1. **Verify FCM token is saved:**
   ```sql
   SELECT user_id, token, created_at FROM user_notification_tokens ORDER BY created_at DESC LIMIT 5;
   ```

2. **Check notification preference was created:**
   ```sql
   SELECT * FROM notification_prefs WHERE kind = 'reminder' LIMIT 5;
   ```

3. **Check if cron job ran:**
   ```sql
   SELECT * FROM cron.job_run_details WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'daily-fitness-motivation');
   ```

4. **Ensure you're outside quiet hours** (if implemented)

5. **App must have valid FCM token** - Make sure you're logged in and the app ran at least once to get the token

## Next Steps

- Test with the time 2-3 minutes in the future
- Once working, set to your preferred daily time
- For production, consider adjusting cron schedule or adding user timezone support

