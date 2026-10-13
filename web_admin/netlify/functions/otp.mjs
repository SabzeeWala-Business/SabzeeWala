/**
 * Netlify Serverless Function for MSG91 OTP
 * Handles send, verify, and retry server-side using Node.js built-in fetch.
 * Completely eliminates browser CORS and 302 cross-origin redirect errors.
 */

const MSG91_WIDGET_ID = process.env.VITE_MSG91_WIDGET_ID || '366a6c72486d383432333133';
const MSG91_AUTH_TOKEN = process.env.VITE_MSG91_AUTH_KEY || '581008TyjZUr05p26acd2169P1';

export const handler = async (event) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Content-Type': 'application/json',
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Method Not Allowed' }),
    };
  }

  try {
    const payload = JSON.parse(event.body || '{}');
    const { action, phone, otp, reqId } = payload;

    if (action === 'send') {
      if (!phone) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ success: false, error: 'Mobile number is required' }),
        };
      }

      const res = await fetch('https://control.msg91.com/api/v5/widget/sendOtpMobile', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          widgetId: MSG91_WIDGET_ID,
          tokenAuth: MSG91_AUTH_TOKEN,
          identifier: phone,
        }),
      });

      const data = await res.json().catch(() => ({}));
      const type = (data.type || data.status || '').toLowerCase();
      const msg = String(data.message || data.error || '');

      if (type === 'error' || /fail|error|limit|wait|block|invalid|exceed/i.test(msg)) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({
            success: false,
            error: msg || 'MSG91: Could not send OTP. Please retry after 1 minute.',
          }),
        };
      }

      const verificationId = data.reqId || data.requestID || data.requestId || data.message;
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          reqId: String(verificationId),
          message: 'OTP sent successfully',
        }),
      };
    }

    if (action === 'verify') {
      if (!otp) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ success: false, error: 'OTP code is required' }),
        };
      }

      const res = await fetch('https://control.msg91.com/api/v5/widget/verifyOtp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          widgetId: MSG91_WIDGET_ID,
          tokenAuth: MSG91_AUTH_TOKEN,
          reqId: reqId || '',
          otp: String(otp),
        }),
      });

      const data = await res.json().catch(() => ({}));
      const type = (data.type || data.status || '').toLowerCase();
      const msg = (data.message || '').toLowerCase();

      if (type === 'success' || msg.includes('verified') || msg.includes('otp verified')) {
        return {
          statusCode: 200,
          headers: corsHeaders,
          body: JSON.stringify({ success: true, message: 'OTP verified successfully' }),
        };
      }

      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          error: data.message || 'Invalid or expired OTP code. Please check and try again.',
        }),
      };
    }

    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ success: false, error: 'Invalid action requested' }),
    };
  } catch (err) {
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ success: false, error: err.message || 'Server error processing OTP' }),
    };
  }
};
