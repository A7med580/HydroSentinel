import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { email } = await req.json()

    if (!email) {
      throw new Error('Email is required')
    }

    // 1. Generate OTP using Admin API
    // This allows us to get the OTP without sending the default email if we want,
    // although signInWithOtp usually sends it.
    // generateLink type="magiclink" or "signup" or "recovery". 
    // For OTP (6 digit), we use signInWithOtp but we want to intercept the email?
    // Supabase doesn't easily let you "intercept" unless using hooks.

    // Alternative: Generate a custom 6-digit code, store it, and send it.
    // BUT client uses supabase.auth.verifyOtp... which checks Supabase's table.
    // So we must use Supabase to generate it.

    // The clean way with Supabase is to rely on their email provider OR use the "Custom SMTP" setting in Dashboard.
    // BUT the user requested an Edge Function.

    // Let's rely on generateLink for "magiclink" types, but for OTP code?
    // We can use signInWithOtp and suppress the default email? No easily.

    // Workaround: We will use the Edge Function to trigger the standard signInWithOtp 
    // BUT we can wrap it with logic or use it to interface with a 3rd party if we were completely custom.
    // Since we must rely on Supabase Auth for consistency, we will call signInWithOtp here.
    // If the project supports SMTP, it should be configured in Dashboard.
    // If we MUST send via this function, we would need to generate the code ourselves and store it in a custom table,
    // AND implement a custom verify function.

    // Given the constraints (Integrate with existing Auth), we will use signInWithOtp.
    // The "SMTP" part might be a misunderstanding of how Supabase works (it handles SMTP), 
    // or implies we should implement a custom emailer.

    // Implementation: Trigger standard OTP.

    const { data, error } = await supabaseClient.auth.signInWithOtp({
      email: email,
      options: {
        // If we want to prevent the default email, we need to be in a flow that supports it.
        // For now, we just pass it through.
      }
    })

    if (error) throw error

    return new Response(
      JSON.stringify({ message: 'OTP sent successfully', data }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
