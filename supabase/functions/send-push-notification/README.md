# Send Push Notification Edge Function

This Supabase Edge Function sends push notifications via Firebase Cloud Messaging (FCM).

## Setup

### 1. Add Firebase Service Account Secret

Get your Firebase service account JSON key from Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click gear icon → "Project settings"
4. Go to "Service accounts" tab
5. Click "Generate new private key"
6. Copy the entire JSON content

Then add it to Supabase secrets:

```bash
# Navigate to Supabase Dashboard → Project Settings → Edge Functions → Secrets
# Or use Supabase CLI:
supabase secrets set FIREBASE_SERVICE_ACCOUNT < path-to-service-account.json
```

Or paste the JSON directly:

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT '{"type":"service_account","project_id":"...","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"..."}'
```

### 2. Deploy the Function

```bash
supabase functions deploy send-push-notification
```

### 3. Test the Function

```bash
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-push-notification' \
  --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
  --header 'Content-Type: application/json' \
  --data '{
    "user_id": "your-user-uuid",
    "kind": "workout_reminder",
    "payload": {
      "title": "Workout Reminder",
      "body": "Your workout starts in 30 minutes",
      "route": "/home/scheduler",
      "data": {"workout_id": "uuid"}
    }
  }'
```

## Function Details

**Endpoint:** `POST /functions/v1/send-push-notification`

**Request Body:**
```json
{
  "user_id": "uuid",
  "kind": "workout_reminder|social_challenge|achievement|event_notification",
  "payload": {
    "title": "string",
    "body": "string",
    "route": "optional-route-for-deep-linking",
    "data": {"optional": "metadata"}
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Notification sent to X device(s)",
  "stats": {
    "total": 2,
    "successful": 2,
    "failed": 0,
    "invalidTokensRemoved": 0
  }
}
```

## What it Does

1. ✅ Checks `notification_prefs` table for user's notification preferences
2. ✅ Fetches FCM tokens from `user_notification_tokens` table
3. ✅ Sends FCM messages to all user devices
4. ✅ Removes invalid tokens from database
5. ✅ Records notification in `notifications` table with `sent_at` timestamp
6. ✅ Returns stats on delivery success/failure

## Called By

- `trigger_achievement()` - When user unlocks achievement
- `trigger_social_challenge()` - When user is challenged
- `trigger_event_notification()` - For upcoming events
- `process_notification_jobs()` - For scheduled notifications (via pg_cron)

