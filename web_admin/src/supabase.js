import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const OTP_SESSION_KEY = 'sabzee_admin_otp_session';

/** Persist MSG91 OTP admin session (mirrors mobile app auth, not Supabase Auth) */
export function saveOtpSession(session) {
  localStorage.setItem(OTP_SESSION_KEY, JSON.stringify(session));
}

export function getOtpSession() {
  try {
    const raw = localStorage.getItem(OTP_SESSION_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function clearOtpSession() {
  localStorage.removeItem(OTP_SESSION_KEY);
}

export function buildOtpSession({ phone, name, token, role = 'admin' }) {
  return {
    access_token: token || `otp_${phone}`,
    user: {
      id: String(phone).replace(/\D/g, '').slice(-10),
      phone,
      email: null,
      user_metadata: { name: name || 'Admin', auth_via: 'msg91_otp' },
      app_metadata: { role },
    },
  };
}
