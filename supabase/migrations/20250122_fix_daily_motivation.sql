-- Fix Daily Motivation Notification System

-- 1. Update set_daily_motivation_time to accept hour and minute
CREATE OR REPLACE FUNCTION set_daily_motivation_time(
  p_user_id UUID,
  p_hour INTEGER,
  p_minute INTEGER,
  p_time_zone TEXT DEFAULT 'America/New_York'
)
RETURNS jsonb AS $$
DECLARE
  v_time TIME;
BEGIN
  -- Validate inputs
  IF p_hour < 0 OR p_hour > 23 OR p_minute < 0 OR p_minute > 59 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid time format');
  END IF;

  -- Create time object
  v_time := make_time(p_hour, p_minute, 0.0);

  -- Delete old reminder preference if exists (to ensure clean slate)
  DELETE FROM notification_prefs 
  WHERE user_id = p_user_id AND kind = 'reminder';

  -- Insert new preference
  -- Note: Using 'reminder' as the kind for daily motivation to distinguish from generic events
  INSERT INTO notification_prefs (user_id, kind, enabled, daily_motivation_time, time_zone)
  VALUES (p_user_id, 'reminder', true, v_time, p_time_zone)
  ON CONFLICT (user_id, kind) DO UPDATE
  SET daily_motivation_time = v_time, 
      time_zone = p_time_zone, 
      enabled = true,
      updated_at = NOW();
  
  RETURN jsonb_build_object('success', true, 'message', 'Time updated to ' || v_time::TEXT);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create send_daily_motivation_via_fcm to check per-user time
CREATE OR REPLACE FUNCTION send_daily_motivation_via_fcm()
RETURNS void AS $$
DECLARE
  v_user RECORD;
  v_user_time TIME;
  v_current_time_in_zone TIME;
  v_motivation_messages TEXT[] := ARRAY[
    '☀️ Good morning! Ready to crush your fitness goals today?',
    '💪 Your workout is waiting for you! Let''s make today count.',
    '🔥 Time to get moving! Check your schedule and get started.',
    '📅 Don''t break the streak! Log your workout today.',
    '🎯 Every workout counts. Make today count!',
    '🌟 Your future self will thank you for working out today.',
    '💯 Strong body, strong mind. Let''s do this!',
    '✨ The only bad workout is the one you didn''t do.'
  ];
  v_random_message TEXT;
BEGIN
  -- Loop through all users with enabled reminders
  FOR v_user IN
    SELECT user_id, daily_motivation_time, time_zone
    FROM notification_prefs
    WHERE kind = 'reminder' AND enabled = true AND daily_motivation_time IS NOT NULL
  LOOP
    -- Get current time in user's timezone
    -- Default to America/New_York if null, though it should be set
    v_current_time_in_zone := (NOW() AT TIME ZONE COALESCE(v_user.time_zone, 'America/New_York'))::TIME;
    
    -- Check if current hour and minute match user's preference
    -- We check if the difference is less than 1 minute to handle slight execution delays
    -- But simplest is just matching hour and minute
    IF EXTRACT(HOUR FROM v_current_time_in_zone) = EXTRACT(HOUR FROM v_user.daily_motivation_time) AND
       EXTRACT(MINUTE FROM v_current_time_in_zone) = EXTRACT(MINUTE FROM v_user.daily_motivation_time) THEN
       
       -- Pick random message
       v_random_message := v_motivation_messages[floor(random() * array_length(v_motivation_messages, 1) + 1)];
       
       -- Check if we already created a job for this user today (to prevent duplicates if cron runs multiple times in same minute)
       -- This is a simple check, might need more robust deduping if critical
       IF NOT EXISTS (
         SELECT 1 FROM notification_jobs 
         WHERE user_id = v_user.user_id 
           AND kind = 'reminder' 
           AND created_at > NOW() - INTERVAL '5 minutes'
       ) THEN
         -- Insert notification job
         INSERT INTO notification_jobs (user_id, kind, run_at, payload, status)
         VALUES (
           v_user.user_id,
           'reminder', -- matching the kind in prefs
           NOW(),
           jsonb_build_object(
             'title', '💪 Daily Fitness Reminder',
             'body', v_random_message,
             'route', '/home'
           ),
           'pending'
         );
       END IF;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update pg_cron schedule to run every minute
-- First unschedule the old job if it exists
SELECT cron.unschedule('daily-fitness-motivation');

-- Schedule new job to run every minute
SELECT cron.schedule(
  'daily-fitness-motivation',
  '* * * * *', -- Every minute
  'SELECT send_daily_motivation_via_fcm();'
);
