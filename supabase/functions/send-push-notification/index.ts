import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { initializeApp, cert, getApps } from 'npm:firebase-admin@12.0.0/app';
import { getMessaging } from 'npm:firebase-admin@12.0.0/messaging';

// Initialize Firebase Admin SDK from secrets
const initFirebaseAdmin = () => {
  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  
  if (!serviceAccountJson) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT secret not found');
  }

  const serviceAccount = JSON.parse(serviceAccountJson);

  if (getApps().length === 0) {
    initializeApp({
      credential: cert({
        projectId: serviceAccount.project_id,
        clientEmail: serviceAccount.client_email,
        privateKey: serviceAccount.private_key.replace(/\\n/g, '\n'),
      }),
    });
  }

  return getMessaging();
};

interface RequestBody {
  user_id: string;
  kind: 'workout_reminder' | 'social_challenge' | 'achievement' | 'event_notification';
  payload: {
    title: string;
    body: string;
    route?: string;
    data?: Record<string, unknown>;
  };
}

serve(async (req) => {
  try {
    // CORS headers
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      });
    }

    // Parse request body
    const { user_id, kind, payload }: RequestBody = await req.json();

    if (!user_id || !kind || !payload) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: user_id, kind, payload' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Step 1: Check notification preferences
    const { data: prefs, error: prefsError } = await supabase
      .from('notification_prefs')
      .select('enabled')
      .eq('user_id', user_id)
      .eq('kind', kind)
      .maybeSingle();

    if (prefsError) {
      console.error('Error checking notification prefs:', prefsError);
      return new Response(
        JSON.stringify({
          error: 'Failed to check notification preferences',
          details: prefsError.message,
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // If preferences exist and enabled is false, skip sending
    if (prefs && prefs.enabled === false) {
      console.log(`Notification skipped: user ${user_id} has disabled ${kind} notifications`);
      return new Response(
        JSON.stringify({
          message: 'Notification skipped: user has disabled this notification type',
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Step 2: Get user's FCM tokens
    const { data: tokens, error: tokensError } = await supabase
      .from('user_notification_tokens')
      .select('token')
      .eq('user_id', user_id);

    if (tokensError) {
      console.error('Error fetching tokens:', tokensError);
      return new Response(
        JSON.stringify({
          error: 'Failed to fetch user FCM tokens',
          details: tokensError.message,
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log(`No tokens found for user ${user_id}`);
      return new Response(
        JSON.stringify({ message: 'No tokens found for user' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Step 3: Initialize Firebase Admin SDK
    const messaging = initFirebaseAdmin();
    const fcmTokens = tokens.map((t: { token: string }) => t.token);

    // Step 4: Extract title and body from payload
    const { title, body, route, data } = payload;

    // Step 5: Send FCM messages
    const fcmPayload = {
      notification: {
        title,
        body,
      },
      data: {
        kind,
        ...(route && { route }),
        ...(data && { data: JSON.stringify(data) }),
      },
      android: {
        priority: 'high' as const,
        notification: {
          channelId: 'fitness_notification_channel',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    let successCount = 0;
    let failureCount = 0;
    const invalidTokens: string[] = [];

    // Send to each token
    for (const token of fcmTokens) {
      try {
        await messaging.send({
          ...fcmPayload,
          token,
        });
        successCount++;
      } catch (error: unknown) {
        const err = error as { code?: string; message?: string };
        console.error(`Error sending to token ${token}:`, err);
        failureCount++;

        // Check if token is invalid (should be removed from DB)
        if (
          err.code === 'messaging/invalid-registration-token' ||
          err.code === 'messaging/registration-token-not-registered'
        ) {
          invalidTokens.push(token);
        }
      }
    }

    // Step 6: Remove invalid tokens from database
    if (invalidTokens.length > 0) {
      await supabase
        .from('user_notification_tokens')
        .delete()
        .eq('user_id', user_id)
        .in('token', invalidTokens);

      console.log(`Removed ${invalidTokens.length} invalid tokens for user ${user_id}`);
    }

    // Step 7: Insert notification record into notifications table
    const { error: notificationError } = await supabase.from('notifications').insert({
      user_id,
      kind,
      payload,
      sent_at: new Date().toISOString(),
    });

    if (notificationError) {
      console.error('Error inserting notification record:', notificationError);
      // Don't fail the request if notification insert fails, just log it
    }

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        message: `Notification sent to ${successCount} device(s)`,
        stats: {
          total: fcmTokens.length,
          successful: successCount,
          failed: failureCount,
          invalidTokensRemoved: invalidTokens.length,
        },
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (error: unknown) {
    const err = error as { message?: string };
    console.error('Edge Function error:', err);
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: err.message,
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
});

