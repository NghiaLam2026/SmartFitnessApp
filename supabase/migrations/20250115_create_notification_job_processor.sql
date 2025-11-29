-- Create job processor function for notifications
-- Migration: Create notification job processor

-- Background job processor function
CREATE OR REPLACE FUNCTION process_notification_jobs()
RETURNS void AS $$
DECLARE
  v_job RECORD;
BEGIN
  -- Get all pending jobs that are ready to run, 100 at a time
  FOR v_job IN
    SELECT id, user_id, kind, payload FROM notification_jobs
    WHERE status = 'pending' AND run_at <= NOW()
    LIMIT 100
  LOOP
    BEGIN
      -- Update job status to processing
      UPDATE notification_jobs SET status = 'processing' WHERE id = v_job.id;

      -- Call Edge Function to send notification
      PERFORM net.http_post(
        'https://' || current_setting('app.supabase_url') || '/functions/v1/quickapi',
        jsonb_build_object(
          'user_id', v_job.user_id,
          'kind', v_job.kind,
          'payload', v_job.payload
        ),
        'Bearer ' || current_setting('app.supabase_anon_key')
      );

      -- Mark as completed successfully
      UPDATE notification_jobs SET status = 'completed' WHERE id = v_job.id;

    EXCEPTION WHEN OTHERS THEN
      -- Mark as failed with error message
      UPDATE notification_jobs 
      SET status = 'failed', last_error = SQLERRM 
      WHERE id = v_job.id;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule pg_cron job to run every minute (requires pg_cron extension to be enabled)
-- Run this in Supabase SQL Editor if pg_cron is available:
-- SELECT cron.schedule('process-notification-jobs', '* * * * *', 'SELECT process_notification_jobs()');

