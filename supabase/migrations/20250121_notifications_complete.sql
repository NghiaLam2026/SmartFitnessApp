-- Complete Notification System Setup
-- Run this file once to set up everything

-- ============================================
-- 1. CREATE TABLES (if they don't exist)
-- ============================================
CREATE TABLE IF NOT EXISTS user_notification_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  device_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id),
  UNIQUE(user_id, token)
);

CREATE TABLE IF NOT EXISTS notification_jobs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  run_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  last_error TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS notification_prefs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  daily_motivation_time TIME DEFAULT '08:00:00',
  time_zone TEXT DEFAULT 'UTC',
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id),
  UNIQUE(user_id, kind)
);

-- ============================================
-- 2. CREATE INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_user_notification_tokens_user_id ON user_notification_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_jobs_user_id ON notification_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_jobs_status ON notification_jobs(status);
CREATE INDEX IF NOT EXISTS idx_notification_jobs_pending ON notification_jobs(status, run_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_sent_at ON notifications(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_prefs_user_id ON notification_prefs(user_id);

-- ============================================
-- 3. ENABLE ROW LEVEL SECURITY
-- ============================================
ALTER TABLE user_notification_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_prefs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users see own tokens" ON user_notification_tokens FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own tokens" ON user_notification_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users see own jobs" ON notification_jobs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users see own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users see own prefs" ON notification_prefs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own prefs" ON notification_prefs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own prefs" ON notification_prefs FOR UPDATE USING (auth.uid() = user_id);

-- ============================================
-- 4. NOTIFICATION PROCESSOR FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION process_notification_jobs()
RETURNS void AS $$
DECLARE
  v_job RECORD;
BEGIN
  FOR v_job IN
    SELECT id, user_id, kind, payload 
    FROM notification_jobs
    WHERE status = 'pending' AND run_at <= NOW()
    ORDER BY run_at ASC
    LIMIT 50
  LOOP
    BEGIN
      UPDATE notification_jobs SET status = 'processing' WHERE id = v_job.id;
      
      INSERT INTO notifications (user_id, kind, payload, sent_at)
      VALUES (v_job.user_id, v_job.kind, v_job.payload, NOW());

      UPDATE notification_jobs 
      SET status = 'completed', processed_at = NOW(), last_error = NULL
      WHERE id = v_job.id;

    EXCEPTION WHEN OTHERS THEN
      UPDATE notification_jobs 
      SET status = 'failed', last_error = SQLERRM, processed_at = NOW()
      WHERE id = v_job.id;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5. SEND NOTIFICATION IMMEDIATELY (from app)
-- ============================================
CREATE OR REPLACE FUNCTION send_notification_now(
  p_user_id UUID,
  p_kind TEXT,
  p_title TEXT,
  p_body TEXT,
  p_route TEXT DEFAULT '/home'
)
RETURNS jsonb AS $$
BEGIN
  INSERT INTO notification_jobs (user_id, kind, run_at, payload, status)
  VALUES (p_user_id, p_kind, NOW(),
    jsonb_build_object('title', p_title, 'body', p_body, 'route', p_route),
    'pending');
  
  PERFORM process_notification_jobs();
  
  RETURN jsonb_build_object('success', true, 'message', 'Notification sent');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. NOTIFICATION PREFERENCE MANAGEMENT
-- ============================================
CREATE OR REPLACE FUNCTION set_daily_motivation_time(
  p_user_id UUID,
  p_time TIME,
  p_time_zone TEXT DEFAULT 'UTC'
)
RETURNS jsonb AS $$
BEGIN
  INSERT INTO notification_prefs (user_id, kind, enabled, daily_motivation_time, time_zone)
  VALUES (p_user_id, 'event_notification', true, p_time, p_time_zone)
  ON CONFLICT (user_id, kind) DO UPDATE
  SET daily_motivation_time = p_time, time_zone = p_time_zone, updated_at = NOW();
  
  RETURN jsonb_build_object('success', true, 'message', 'Time updated to ' || p_time::TEXT);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_notification_preferences(p_user_id UUID)
RETURNS TABLE(
  kind TEXT,
  enabled BOOLEAN,
  daily_motivation_time TIME,
  time_zone TEXT,
  quiet_hours_start TIME,
  quiet_hours_end TIME
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    notification_prefs.kind,
    notification_prefs.enabled,
    notification_prefs.daily_motivation_time,
    notification_prefs.time_zone,
    notification_prefs.quiet_hours_start,
    notification_prefs.quiet_hours_end
  FROM notification_prefs
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 7. DAILY MOTIVATION SCHEDULER
-- ============================================
CREATE OR REPLACE FUNCTION send_daily_motivation()
RETURNS void AS $$
DECLARE
  motivation_messages TEXT[] := ARRAY[
    '☀️ Good morning! Ready to crush your fitness goals today?',
    '💪 Your workout is waiting for you! Let''s make today count.',
    '🔥 Time to get moving! Check your schedule and get started.',
    '📅 Don''t break the streak! Log your workout today.',
    '🎯 Every workout counts. Make today count!',
    '🌟 Your future self will thank you for working out today.',
    '💯 Strong body, strong mind. Let''s do this!',
    '✨ The only bad workout is the one you didn''t do.'
  ];
  random_message TEXT;
BEGIN
  random_message := motivation_messages[floor(random() * array_length(motivation_messages, 1) + 1)];
  
  INSERT INTO notification_jobs (user_id, kind, run_at, payload, status)
  SELECT DISTINCT
    user_id,
    'event_notification',
    NOW(),
    jsonb_build_object(
      'title', '💪 Daily Fitness Reminder',
      'body', random_message,
      'route', '/home/scheduler'
    ),
    'pending'
  FROM user_notification_tokens
  WHERE token IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 8. WORKOUT MILESTONE TRIGGER
-- ============================================
CREATE OR REPLACE FUNCTION notify_workout_milestone()
RETURNS TRIGGER AS $$
DECLARE
  workout_count INTEGER;
  milestone_title TEXT;
  milestone_message TEXT;
BEGIN
  SELECT COUNT(*) INTO workout_count
  FROM user_progress
  WHERE user_id = NEW.user_id;

  CASE workout_count
    WHEN 1 THEN
      milestone_title := '🎉 First Workout Complete!';
      milestone_message := 'Amazing start! You''re on your fitness journey!';
    WHEN 3 THEN
      milestone_title := '💪 Three Down!';
      milestone_message := 'You''re building a great habit! Keep going!';
    WHEN 5 THEN
      milestone_title := '🔥 Five Workouts!';
      milestone_message := 'You''re on fire! Keep this momentum!';
    ELSE
      IF workout_count % 10 = 0 THEN
        milestone_title := '🏆 ' || workout_count || ' Workouts!';
        milestone_message := 'Incredible dedication! You''re a fitness champion!';
      ELSE
        RETURN NEW;
      END IF;
  END CASE;

  INSERT INTO notification_jobs (user_id, kind, run_at, payload, status)
  VALUES (
    NEW.user_id,
    'achievement',
    NOW(),
    jsonb_build_object(
      'title', milestone_title,
      'body', milestone_message,
      'route', '/home'
    ),
    'pending'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_workout_milestone ON user_progress;
CREATE TRIGGER trigger_workout_milestone
  AFTER INSERT ON user_progress
  FOR EACH ROW
  EXECUTE FUNCTION notify_workout_milestone();

-- ============================================
-- 9. WELCOME NOTIFICATION FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION send_welcome_notification(p_user_id UUID)
RETURNS void AS $$
BEGIN
  INSERT INTO notification_jobs (user_id, kind, run_at, payload, status)
  VALUES (
    p_user_id,
    'event_notification',
    NOW(),
    jsonb_build_object(
      'title', '🎉 Welcome to Smart Fitness!',
      'body', 'You''re all set! Let''s get started on your fitness journey.',
      'route', '/home'
    ),
    'pending'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 10. SETUP DAILY CRON JOB (optional)
-- ============================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily motivation at 8 AM
SELECT cron.schedule(
  'daily-fitness-motivation',
  '0 8 * * *',
  'SELECT send_daily_motivation();'
) ON CONFLICT (jobname) DO UPDATE SET schedule = EXCLUDED.schedule;

RAISE NOTICE '✅ Notification system setup complete!';

