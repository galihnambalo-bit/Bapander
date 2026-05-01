import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') ?? '';
const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_API_KEY') ?? '';

serve(async (req) => {
  try {
    const { to_user_id, title, body } = await req.json();

    if (!ONESIGNAL_APP_ID || !ONESIGNAL_API_KEY) {
      return new Response(JSON.stringify({ error: 'OneSignal configuration missing' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!to_user_id || !title || !body) {
      return new Response(JSON.stringify({ error: 'to_user_id, title, and body are required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const response = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${ONESIGNAL_API_KEY}`,
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_external_user_ids: [to_user_id],
        headings: { en: title, id: title },
        contents: { en: body, id: body },
        android_channel_id: 'bapander_messages',
      }),
    });

    const result = await response.json();
    return new Response(JSON.stringify({ ok: true, result }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
