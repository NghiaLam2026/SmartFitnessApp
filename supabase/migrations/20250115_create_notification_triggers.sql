-- Create trigger functions for notifications
-- Migration: Create notification trigger functions

-- 1. Trigger function for workout reminders
CREATE OR REPLACE FUNCTION trigger_workout_reminder(
  p_user_id UUID,
  p_workout_id UUID,
  p_workout_name TEXT,
  p_scheduled_time TIMESTAMP WITH TIME ZONE
) RETURNS void AS $$
BEGIN
  INSERT INTO notification_jobs (
    user_id,
    kind,
    run_at,
    payload,
    status
  ) VALUES (
    p_user_id,
    'workout_reminder',
    p_scheduled_time - INTERVAL '30 minutes',
    jsonb_build_object(
      'title', 'Workout Reminder',
      'body', p_workout_name || ' starts in 30 minutes , you Ready to go?',
      'route', '/home/scheduler',
      'data', jsonb_build_object(
        'workout_id', p_workout_id::text,
        'scheduled_time', p_scheduled_time::text
      )
    ),
    'pending'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger function for achievements
CREATE OR REPLACE FUNCTION trigger_achievement(
  p_user_id UUID,
  p_achievement_name TEXT,
  p_achievement_description TEXT
) RETURNS void AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  -- Insert into notifications table
  INSERT INTO notifications (
    user_id,
    kind,
    payload,
    sent_at
  ) VALUES (
    p_user_id,
    'achievement',
    jsonb_build_object(
      'title', 'Achievement Unlocked!',
      'body', p_achievement_description,
      'route', '/home/achievements',
      'data', jsonb_build_object(
        'achievement_name', p_achievement_name
      )
    ),
    NOW()
  ) RETURNING id INTO v_notification_id;

  -- Call Edge Function to send push notification
  PERFORM net.http_post(
    'https://' || current_setting('app.supabase_url') || '/functions/v1/send-push-notification',
    jsonb_build_object(
      'user_id', p_user_id,
      'kind', 'achievement',
      'payload', jsonb_build_object(
        'title', 'Achievement Unlocked!',
        'body', p_achievement_description,
        'route', '/home/achievements',
        'data', jsonb_build_object(
          'achievement_name', p_achievement_name
        )
      )
    ),
    'Bearer ' || current_setting('app.supabase_anon_key')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger function for social challenges
CREATE OR REPLACE FUNCTION trigger_social_challenge(
  p_user_id UUID,
  p_challenge_id UUID,
  p_challenge_name TEXT,
  p_challenger_name TEXT
) RETURNS void AS $$
BEGIN
  INSERT INTO notifications (
    user_id,
    kind,
    payload,
    sent_at
  ) VALUES (
    p_user_id,
    'social_challenge',
    jsonb_build_object(
      'title', 'New Challenge!',
      'body', p_challenger_name || ' challenged you to ' || p_challenge_name,
      'route', '/home/challenges',
      'data', jsonb_build_object(
        'challenge_id', p_challenge_id::text,
        'challenge_name', p_challenge_name,
        'challenger_name', p_challenger_name
      )
    ),
    NOW()
  );

  PERFORM net.http_post(
    'https://' || current_setting('app.supabase_url') || '/functions/v1/send-push-notification',
    jsonb_build_object(
      'user_id', p_user_id,
      'kind', 'social_challenge',
      'payload', jsonb_build_object(
        'title', 'New Challenge!',
        'body', p_challenger_name || ' challenged you to ' || p_challenge_name,
        'route', '/home/challenges',
        'data', jsonb_build_object(
          'challenge_id', p_challenge_id::text,
          'challenge_name', p_challenge_name,
          'challenger_name', p_challenger_name
        )
      )
    ),
    'Bearer ' || current_setting('app.supabase_anon_key')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Trigger function for event notifications
CREATE OR REPLACE FUNCTION trigger_event_notification(
  p_user_id UUID,
  p_event_id UUID,
  p_event_name TEXT,
  p_event_location TEXT,
  p_event_time TIMESTAMP WITH TIME ZONE
) RETURNS void AS $$
BEGIN
  INSERT INTO notifications (
    user_id,
    kind,
    payload,
    sent_at
  ) VALUES (
    p_user_id,
    'event_notification',
    jsonb_build_object(
      'title', 'Upcoming Event',
      'body', p_event_name || ' at ' || p_event_location,
      'route', '/home/events',
      'data', jsonb_build_object(
        'event_id', p_event_id::text,
        'event_name', p_event_name,
        'event_location', p_event_location,
        'event_time', p_event_time::text
      )
    ),
    NOW()
  );

  PERFORM net.http_post(
    'https://' || current_setting('app.supabase_url') || '/functions/v1/send-push-notification',
    jsonb_build_object(
      'user_id', p_user_id,
      'kind', 'event_notification',
      'payload', jsonb_build_object(
        'title', 'Upcoming Event',
        'body', p_event_name || ' at ' || p_event_location,
        'route', '/home/events',
        'data', jsonb_build_object(
          'event_id', p_event_id::text,
          'event_name', p_event_name,
          'event_location', p_event_location,
          'event_time', p_event_time::text
        )
      )
    ),
    'Bearer ' || current_setting('app.supabase_anon_key')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

