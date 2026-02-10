
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// 1. We grab the keys securely from the cloud environment
// We recycle the existing key or a new one. User said "I will set the API Key".
// We will use 'SENDGRID_API_KEY' as standard practice.
const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY')
const TEMPLATE_ID = 'd-a065eb55121b44b2aead329f6b3513df' // <--- RISK ACCEPTANCE TEMPLATE

serve(async (req) => {
  // 2. We allow the Flutter app to talk to this function (CORS)
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    // 3. Receive the Email and OTP from Flutter
    const { email, otp } = await req.json()

    // 4. Send the command to SendGrid
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        personalizations: [{
          to: [{ email: email }],
          dynamic_template_data: {
            "otp_code": otp,  // This fills the {{otp_code}} in your design
          }
        }],
        from: { email: 'ahmedcusorrrr@gmail.com', name: 'HydroSentinel Security' }, // Use verified sender
        template_id: TEMPLATE_ID,
      }),
    })

    if (!response.ok) throw new Error(await response.text())

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
