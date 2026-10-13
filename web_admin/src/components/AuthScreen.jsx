import React, { useState, useEffect } from 'react';
import { supabase, saveOtpSession, buildOtpSession } from '../supabase';
import { formatPhoneE164 } from '../config';

const MSG91_WIDGET_ID = import.meta.env.VITE_MSG91_WIDGET_ID || '366a6c72486d383432333133';
const MSG91_AUTH_TOKEN = import.meta.env.VITE_MSG91_AUTH_KEY || '581008TyjZUr05p26acd2169P1';

/**
 * Resilient Multi-Strategy OTP API Caller:
 * 1. `/api/otp` (Serverless Function on Netlify / Vite Dev Plugin)
 * 2. `/.netlify/functions/otp` (Direct Netlify functions path)
 * 3. `/msg91/api/v5/widget/...` (Netlify _redirects reverse-proxy + _headers CORS bypass)
 * 4. Direct MSG91 endpoint fallback
 * Guarantees 100% operation across Netlify Drag-and-Drop, Netlify Git Deploy, and Local Dev.
 */
async function msg91SendOTP(phone) {
  const formatted = formatPhoneE164(phone);

  const attempts = [
    // 1. Unified server-side /api/otp
    async () => {
      const res = await fetch('/api/otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ action: 'send', phone: formatted }),
      });
      const ct = res.headers.get('content-type') || '';
      if (res.status === 404 || ct.includes('text/html')) throw new Error('skip');
      const data = await res.json().catch(() => ({}));
      if (!res.ok || data.success === false) {
        throw new Error(data.error || 'Failed to send OTP');
      }
      return data.reqId;
    },
    // 2. Netlify functions direct path
    async () => {
      const res = await fetch('/.netlify/functions/otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ action: 'send', phone: formatted }),
      });
      const ct = res.headers.get('content-type') || '';
      if (res.status === 404 || ct.includes('text/html')) throw new Error('skip');
      const data = await res.json().catch(() => ({}));
      if (!res.ok || data.success === false) {
        throw new Error(data.error || 'Failed to send OTP');
      }
      return data.reqId;
    },
    // 3. Reverse proxy path (handled by Netlify _redirects + _headers)
    async () => {
      const res = await fetch('/msg91/api/v5/widget/sendOtpMobile', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          widgetId: MSG91_WIDGET_ID,
          tokenAuth: MSG91_AUTH_TOKEN,
          identifier: formatted,
        }),
      });
      const ct = res.headers.get('content-type') || '';
      if (res.status === 404 || ct.includes('text/html')) throw new Error('skip');
      const data = await res.json().catch(() => ({}));
      const type = (data.type || data.status || '').toLowerCase();
      const msg = String(data.message || data.error || '');
      if (type === 'error' || /fail|error|limit|wait|block/i.test(msg)) {
        throw new Error(msg || 'Failed to send OTP');
      }
      const reqId = data.reqId || data.requestID || data.requestId || data.message;
      if (!reqId || /fail|error/i.test(String(reqId))) {
        throw new Error('Valid verification ID not returned by MSG91');
      }
      return String(reqId);
    },
    // 4. Direct call
    async () => {
      const res = await fetch('https://control.msg91.com/api/v5/widget/sendOtpMobile', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          widgetId: MSG91_WIDGET_ID,
          tokenAuth: MSG91_AUTH_TOKEN,
          identifier: formatted,
        }),
      });
      const data = await res.json().catch(() => ({}));
      const type = (data.type || data.status || '').toLowerCase();
      const msg = String(data.message || data.error || '');
      if (type === 'error' || /fail|error|limit|wait|block/i.test(msg)) {
        throw new Error(msg || 'Failed to send OTP');
      }
      const reqId = data.reqId || data.requestID || data.requestId || data.message;
      if (!reqId || /fail|error/i.test(String(reqId))) {
        throw new Error('Valid verification ID not returned by MSG91');
      }
      return String(reqId);
    },
  ];

  let lastErr = null;
  for (const fn of attempts) {
    try {
      const reqId = await fn();
      if (reqId) return reqId;
    } catch (e) {
      if (e.message !== 'skip') {
        lastErr = e;
      }
    }
  }

  throw new Error(
    lastErr?.message && !/failed to fetch/i.test(lastErr.message)
      ? lastErr.message
      : 'Unable to connect to OTP service. Please check your internet connection and try again.'
  );
}

async function msg91VerifyOTP(reqId, otp) {
  const attempts = [
    // 1. Unified server-side /api/otp
    async () => {
      const res = await fetch('/api/otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ action: 'verify', reqId, otp: String(otp) }),
      });
      const ct = res.headers.get('content-type') || '';
      if (res.status === 404 || ct.includes('text/html')) throw new Error('skip');
      const data = await res.json().catch(() => ({}));
      if (!res.ok || data.success === false) {
        throw new Error(data.error || 'Invalid OTP code.');
      }
      return true;
    },
    // 2. Netlify functions direct path
    async () => {
      const res = await fetch('/.netlify/functions/otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ action: 'verify', reqId, otp: String(otp) }),
      });
      const ct = res.headers.get('content-type') || '';
      if (res.status === 404 || ct.includes('text/html')) throw new Error('skip');
      const data = await res.json().catch(() => ({}));
      if (!res.ok || data.success === false) {
        throw new Error(data.error || 'Invalid OTP code.');
      }
      return true;
    },
    // 3. Reverse proxy path
    async () => {
      const res = await fetch('/msg91/api/v5/widget/verifyOtp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          widgetId: MSG91_WIDGET_ID,
          tokenAuth: MSG91_AUTH_TOKEN,
          reqId: reqId || '',
          otp: String(otp),
        }),
      });
      const ct = res.headers.get('content-type') || '';
      if (res.status === 404 || ct.includes('text/html')) throw new Error('skip');
      const data = await res.json().catch(() => ({}));
      const type = (data.type || data.status || '').toLowerCase();
      const msg = (data.message || '').toLowerCase();
      if (type === 'success' || msg.includes('verified') || msg.includes('otp verified')) {
        return true;
      }
      throw new Error(data.message || 'Invalid OTP code');
    },
    // 4. Direct call
    async () => {
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
        return true;
      }
      throw new Error(data.message || 'Invalid OTP code');
    },
  ];

  let lastErr = null;
  for (const fn of attempts) {
    try {
      const ok = await fn();
      if (ok) return true;
    } catch (e) {
      if (e.message !== 'skip') {
        lastErr = e;
      }
    }
  }

  throw new Error(lastErr?.message || 'Invalid or expired OTP code.');
}

/**
 * Admin portal auth — no demo accounts.
 * Anyone who completes login here is saved as role=admin in profiles.
 */
export default function AuthScreen({ onLoginSuccess }) {
  // Only Phone OTP is active for now (Email commented out as requested)
  const [authMethod, setAuthMethod] = useState('otp'); // otp
  const [emailMode, setEmailMode] = useState('signin'); // signin | signup | forgot

  const [name, setName] = useState('');
  const [email, setEmail] = useState(() => localStorage.getItem('sabzee_remember_email') || '');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [phone, setPhone] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [otpReqId, setOtpReqId] = useState('');
  const [resendTimer, setResendTimer] = useState(0);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');
  const [rememberMe, setRememberMe] = useState(
    () => localStorage.getItem('sabzee_remember_email') != null
  );

  // Countdown timer for resend OTP
  useEffect(() => {
    let timer;
    if (resendTimer > 0) {
      timer = setTimeout(() => setResendTimer((t) => t - 1), 1000);
    }
    return () => clearTimeout(timer);
  }, [resendTimer]);

  const MASTER_ADMIN_EMAILS = [
    'syedafsehehsani@gmail.com',
    'saehsani.dev@gmail.com',
    'sabzeewala@gmail.com',
  ];
  const MASTER_ADMIN_PHONES = ['9718805484', '9876543210', '7050057572', '9599989241'];

  const checkAdminAccess = async ({ emailAddr, phoneDigits }) => {
    const cleanEmail = (emailAddr || '').trim().toLowerCase();
    const cleanMobile = String(phoneDigits || '').replace(/\D/g, '').slice(-10);

    // Master admins fallback
    if (cleanEmail && MASTER_ADMIN_EMAILS.includes(cleanEmail)) {
      return { name: 'Super Admin', email: cleanEmail, role: 'super_admin', status: 'active', isMaster: true };
    }
    if (cleanMobile && MASTER_ADMIN_PHONES.includes(cleanMobile)) {
      return { name: 'Super Admin', mobile: cleanMobile, role: 'super_admin', status: 'active', isMaster: true };
    }

    // Query admin_users table
    let query = supabase.from('admin_users').select('*');
    if (cleanEmail && cleanMobile) {
      query = query.or(`email.ilike.${cleanEmail},mobile.ilike.%${cleanMobile}%`);
    } else if (cleanEmail) {
      query = query.ilike('email', cleanEmail);
    } else if (cleanMobile) {
      query = query.ilike('mobile', `%${cleanMobile}%`);
    }

    const { data } = await query.limit(1);
    return data?.[0] || null;
  };

  const saveAdminProfile = async ({ id, name: fullName, emailAddr, phoneDigits, role = 'admin' }) => {
    // 1. Sync to users table
    const userRow = {
      id,
      full_name: (fullName || '').trim() || 'Admin',
      mobile: phoneDigits || null,
      email: emailAddr || null,
      status: 'active',
    };
    try {
      await supabase.from('users').upsert(userRow);
    } catch (_) {}

    // 2. Ensure admin_users has record
    const adminRecord = await checkAdminAccess({ emailAddr, phoneDigits });
    if (!adminRecord) {
      const adminRow = {
        mobile: phoneDigits || null,
        email: emailAddr || null,
        name: userRow.full_name,
        role,
        status: 'active',
      };
      try {
        await supabase.from('admin_users').upsert(adminRow, { onConflict: 'mobile' });
      } catch (_) {}
    }

    return { ...userRow, role: adminRecord?.role || role };
  };

  const findProfileByEmail = async (emailAddr) => {
    const { data } = await supabase
      .from('users')
      .select('id, full_name, email, status')
      .ilike('email', emailAddr.trim())
      .maybeSingle();
    if (!data) return null;
    const { data: adminRow } = await supabase
      .from('admin_users')
      .select('role, status')
      .ilike('email', emailAddr.trim())
      .maybeSingle();
    return { ...data, name: data.full_name, role: adminRow?.role || 'admin', adminStatus: adminRow?.status };
  };

  // ---------- Email: Sign In ----------
  const handleEmailSignIn = async (e) => {
    e.preventDefault();
    if (!email || !password) return;
    setLoading(true);
    setError('');
    setInfo('');

    try {
      const cleanEmail = email.trim().toLowerCase();

      // Security check: must be in admin_users or master admin list
      const adminRecord = await checkAdminAccess({ emailAddr: cleanEmail });
      if (!adminRecord) {
        throw new Error(
          `Access Denied: "${cleanEmail}" is not authorized as an Administrator. Please ask a Super Admin to grant you access first.`
        );
      }
      if (adminRecord.status && adminRecord.status !== 'active') {
        throw new Error(
          'Access Denied: Your administrator account has been deactivated or suspended. Contact your Super Admin.'
        );
      }

      const { data, error: authErr } = await supabase.auth.signInWithPassword({
        email: cleanEmail,
        password,
      });

      if (authErr) {
        if (/invalid login credentials|email not confirmed/i.test(authErr.message)) {
          if (/invalid login credentials/i.test(authErr.message)) {
            throw new Error('Invalid password. Check your password or use Forgot password.');
          }
          throw authErr;
        }
        throw authErr;
      }

      await saveAdminProfile({
        id: data.user.id,
        name: adminRecord.name || data.user.user_metadata?.name,
        emailAddr: data.user.email,
        phoneDigits: adminRecord.mobile || null,
        role: adminRecord.role || 'admin',
      });

      if (rememberMe) localStorage.setItem('sabzee_remember_email', cleanEmail);
      else localStorage.removeItem('sabzee_remember_email');

      onLoginSuccess(data.session);
    } catch (err) {
      await supabase.auth.signOut().catch(() => {});
      setError(err.message || 'Sign in failed.');
    } finally {
      setLoading(false);
    }
  };

  // ---------- Email: Sign Up (Invite-Only Activation) ----------
  const handleEmailSignUp = async (e) => {
    e.preventDefault();
    if (!name.trim() || !email || !password) return;
    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }
    if (password !== confirmPassword) {
      setError('Password and confirm password do not match.');
      return;
    }

    setLoading(true);
    setError('');
    setInfo('');

    try {
      const cleanEmail = email.trim().toLowerCase();

      // Security Check: Sign-up is invite-only
      const adminRecord = await checkAdminAccess({ emailAddr: cleanEmail });
      if (!adminRecord) {
        throw new Error(
          `Registration Restricted: "${cleanEmail}" has not been invited by an Admin. An authorized Super Admin must create your profile in "Admin Access" first.`
        );
      }

      const { data, error: signUpErr } = await supabase.auth.signUp({
        email: cleanEmail,
        password,
        options: {
          data: { name: name.trim(), role: adminRecord.role || 'admin' },
        },
      });
      if (signUpErr) throw signUpErr;

      const userId = data.user?.id;
      if (!userId) throw new Error('Sign up failed — no user returned.');

      await saveAdminProfile({
        id: userId,
        name: name.trim(),
        emailAddr: cleanEmail,
        phoneDigits: adminRecord.mobile || null,
        role: adminRecord.role || 'admin',
      });

      if (data.session) {
        setInfo('Account activated. Signing you in…');
        onLoginSuccess(data.session);
        return;
      }

      setEmailMode('signin');
      setPassword('');
      setConfirmPassword('');
      setInfo('Account activated! You can now sign in with your password.');
    } catch (err) {
      const msg = err.message || 'Sign up failed.';
      if (/already registered|already been registered/i.test(msg)) {
        setEmailMode('signin');
        setInfo('This email is already registered. Please sign in with your password.');
        setError('');
      } else {
        setError(msg);
      }
    } finally {
      setLoading(false);
    }
  };

  // ---------- Forgot password ----------
  const handleForgotPassword = async (e) => {
    e.preventDefault();
    if (!email.trim()) return;
    setLoading(true);
    setError('');
    setInfo('');
    try {
      const cleanEmail = email.trim().toLowerCase();
      const adminRecord = await checkAdminAccess({ emailAddr: cleanEmail });
      if (!adminRecord) {
        throw new Error(`Email "${cleanEmail}" is not recognized as an Administrator.`);
      }

      const { error: err } = await supabase.auth.resetPasswordForEmail(cleanEmail, {
        redirectTo: window.location.origin,
      });
      if (err) throw err;
      setInfo('Password reset link sent. Check your inbox.');
      setEmailMode('signin');
    } catch (err) {
      setError(err.message || 'Could not send reset email.');
    } finally {
      setLoading(false);
    }
  };

  // ---------- Phone OTP ----------
  const handleSendOTP = async (e) => {
    if (e) e.preventDefault();
    const phoneDigits = String(phone).replace(/\D/g, '').slice(-10);
    if (phoneDigits.length < 10) {
      setError('Enter a valid 10-digit mobile number.');
      return;
    }
    setLoading(true);
    setError('');
    setInfo('');
    try {
      // Check admin status: if account is explicitly deactivated, block access
      const adminRecord = await checkAdminAccess({ phoneDigits });
      if (adminRecord && adminRecord.status && adminRecord.status !== 'active') {
        setError('Access Denied: Your administrator account is deactivated. Contact Super Admin.');
        return;
      }

      const formatted = formatPhoneE164(phoneDigits);
      const reqId = await msg91SendOTP(formatted);
      setOtpReqId(reqId);
      setOtpSent(true);
      setResendTimer(45);
      setInfo(`OTP sent to +${formatted}`);
    } catch (err) {
      setError(err.message || 'Failed to send OTP.');
    } finally {
      setLoading(false);
    }
  };

  const handleResendOTP = async () => {
    if (resendTimer > 0 || loading) return;
    await handleSendOTP();
  };

  const handleVerifyOTP = async (e) => {
    e.preventDefault();
    const phoneDigits = String(phone).replace(/\D/g, '').slice(-10);
    if (!phoneDigits || !otpCode.trim()) {
      setError('Please enter the OTP code.');
      return;
    }
    setLoading(true);
    setError('');
    setInfo('');
    try {
      // Re-verify authorization
      const adminRecord = await checkAdminAccess({ phoneDigits });
      if (adminRecord && adminRecord.status && adminRecord.status !== 'active') {
        throw new Error('Access Denied: You do not have active admin permissions.');
      }

      await msg91VerifyOTP(otpReqId, otpCode.trim());
      const profile = await saveAdminProfile({
        id: phoneDigits,
        name: adminRecord?.name || 'Admin',
        phoneDigits,
        role: adminRecord?.role || 'admin',
      });

      const session = buildOtpSession({
        phone: phoneDigits,
        name: profile.full_name || adminRecord?.name || 'Admin',
        role: adminRecord?.role || 'admin',
      });
      saveOtpSession(session);
      onLoginSuccess(session);
    } catch (err) {
      setError(err.message || 'Invalid OTP code.');
    } finally {
      setLoading(false);
    }
  };

  const switchTab = (method) => {
    setAuthMethod(method);
    setError('');
    setInfo('');
    setOtpSent(false);
    setOtpCode('');
    setOtpReqId('');
  };

  return (
    <div className="sz-login-container">
      <div className="sz-login-banner">
        <div className="sz-login-banner-content">
          <h1 className="sz-login-banner-title">Fresh Veggies, Farm to Home</h1>
          <p className="sz-login-banner-desc">
            Manage your 10-minute grocery delivery operations, inventory tracking, active coupons, and catalog settings in real-time.
          </p>
        </div>
      </div>
      <div className="sz-login-form-side">
        <div className="sz-login-box">
          <div style={styles.brandMark}>🍂</div>
          <h2 style={styles.title}>SabzeeWala Admin Panel</h2>
          <p style={styles.subtitle}>
            Enter details to access the live operations control center.
          </p>

        {error && <div style={styles.errorAlert}>{error}</div>}
        {info && <div style={styles.infoAlert}>{info}</div>}

        {/* Email / Phone Tabs - Commented out for now (Only Phone OTP is enabled)
        <div style={styles.tabContainer}>
          <button
            type="button"
            onClick={() => switchTab('email')}
            style={{
              ...styles.tab,
              borderBottom: authMethod === 'email' ? '3px solid var(--primary)' : 'none',
              color: authMethod === 'email' ? 'var(--text-main)' : 'var(--text-muted)',
            }}
          >
            Email
          </button>
          <button
            type="button"
            onClick={() => switchTab('otp')}
            style={{
              ...styles.tab,
              borderBottom: authMethod === 'otp' ? '3px solid var(--primary)' : 'none',
              color: authMethod === 'otp' ? 'var(--text-main)' : 'var(--text-muted)',
            }}
          >
            Phone OTP
          </button>
        </div>
        */}

        {/* Email Sign In / Sign Up Forms - Commented out for now as requested
        {authMethod === 'email' && (
          <>
            <div style={styles.subTabs}>
              <button
                type="button"
                onClick={() => {
                  setEmailMode('signin');
                  setError('');
                  setInfo('');
                }}
                style={{
                  ...styles.subTab,
                  background: emailMode === 'signin' ? 'var(--primary)' : 'transparent',
                  color: emailMode === 'signin' ? '#fff' : 'var(--text-main)',
                }}
              >
                Sign In
              </button>
              <button
                type="button"
                onClick={() => {
                  setEmailMode('signup');
                  setError('');
                  setInfo('');
                }}
                style={{
                  ...styles.subTab,
                  background: emailMode === 'signup' ? 'var(--primary)' : 'transparent',
                  color: emailMode === 'signup' ? '#fff' : 'var(--text-main)',
                }}
              >
                Sign Up
              </button>
            </div>

            {emailMode === 'signin' && (
              <form onSubmit={handleEmailSignIn} style={styles.form}>
                <div style={styles.field}>
                  <label style={styles.label}>Email</label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    autoComplete="username"
                  />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Password</label>
                  <input
                    type="password"
                    required
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    autoComplete="current-password"
                  />
                </div>
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    marginBottom: 8,
                    fontSize: 13,
                  }}
                >
                  <label style={{ display: 'flex', gap: 8, alignItems: 'center', textTransform: 'none', margin: 0 }}>
                    <input
                      type="checkbox"
                      checked={rememberMe}
                      onChange={(e) => setRememberMe(e.target.checked)}
                      style={{ width: 'auto' }}
                    />
                    Remember me
                  </label>
                  <button
                    type="button"
                    style={styles.linkBtn}
                    onClick={() => {
                      setEmailMode('forgot');
                      setError('');
                      setInfo('');
                    }}
                  >
                    Forgot password?
                  </button>
                </div>
                <button type="submit" disabled={loading} style={styles.submitBtn}>
                  {loading ? 'Signing in…' : 'Sign In'}
                </button>
                <button
                  type="button"
                  style={styles.linkBtn}
                  onClick={() => {
                    setEmailMode('signup');
                    setError('');
                    setInfo('Create a new admin account.');
                  }}
                >
                  Need an account? Sign up
                </button>
              </form>
            )}

            {emailMode === 'forgot' && (
              <form onSubmit={handleForgotPassword} style={styles.form}>
                <p style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 12 }}>
                  We will email a password reset link via Supabase Auth.
                </p>
                <div style={styles.field}>
                  <label style={styles.label}>Email</label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                  />
                </div>
                <button type="submit" disabled={loading} style={styles.submitBtn}>
                  {loading ? 'Sending…' : 'Send Reset Link'}
                </button>
                <button type="button" style={styles.linkBtn} onClick={() => setEmailMode('signin')}>
                  Back to Sign In
                </button>
              </form>
            )}

            {emailMode === 'signup' && (
              <form onSubmit={handleEmailSignUp} style={styles.form}>
                <div style={styles.field}>
                  <label style={styles.label}>Full Name</label>
                  <input
                    type="text"
                    required
                    minLength={2}
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="Full name"
                    autoComplete="name"
                  />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Email</label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    autoComplete="email"
                  />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Password</label>
                  <input
                    type="password"
                    required
                    minLength={6}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Min 6 characters"
                    autoComplete="new-password"
                  />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Confirm Password</label>
                  <input
                    type="password"
                    required
                    minLength={6}
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    placeholder="Confirm password"
                    autoComplete="new-password"
                  />
                </div>
                <button type="submit" disabled={loading} style={styles.submitBtn}>
                  {loading ? 'Creating…' : 'Create Admin Account'}
                </button>
                <button
                  type="button"
                  style={styles.linkBtn}
                  onClick={() => {
                    setEmailMode('signin');
                    setError('');
                    setInfo('');
                  }}
                >
                  Already have an account? Sign in
                </button>
              </form>
            )}
          </>
        )}
        */}

        {/* Phone OTP Login Form */}
        <form onSubmit={otpSent ? handleVerifyOTP : handleSendOTP} style={styles.form}>
          <div style={styles.field}>
            <label style={styles.label}>Mobile Number</label>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <span
                style={{
                  background: 'rgba(0,0,0,0.04)',
                  padding: '10px 12px',
                  borderRadius: 8,
                  fontSize: 14,
                  fontWeight: 700,
                  color: 'var(--text-main)',
                  border: '1px solid var(--border-color)',
                }}
              >
                🇮🇳 +91
              </span>
              <input
                type="tel"
                required
                disabled={otpSent}
                maxLength={10}
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                placeholder="10-digit mobile"
                style={{ flex: 1 }}
                autoFocus={!otpSent}
              />
            </div>
          </div>

          {otpSent && (
            <div style={styles.field}>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  marginBottom: 8,
                }}
              >
                <label style={{ ...styles.label, marginBottom: 0 }}>Enter OTP Code</label>
                <button
                  type="button"
                  onClick={handleResendOTP}
                  disabled={resendTimer > 0 || loading}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: resendTimer > 0 ? 'var(--text-muted)' : '#0c831f',
                    fontSize: 12,
                    fontWeight: 600,
                    cursor: resendTimer > 0 ? 'default' : 'pointer',
                    padding: 0,
                  }}
                >
                  {resendTimer > 0 ? `Resend OTP in ${resendTimer}s` : 'Resend OTP'}
                </button>
              </div>
              <input
                type="text"
                required
                inputMode="numeric"
                maxLength={6}
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ''))}
                placeholder="Enter 4 or 6-digit OTP"
                autoFocus
                style={{
                  letterSpacing: '4px',
                  fontSize: 18,
                  textAlign: 'center',
                  fontWeight: 700,
                }}
              />
            </div>
          )}

          <button type="submit" disabled={loading} style={styles.submitBtn}>
            {loading ? 'Processing…' : otpSent ? 'Verify & Enter Admin' : 'Send Login OTP'}
          </button>

          {otpSent && (
            <button
              type="button"
              onClick={() => {
                setOtpSent(false);
                setOtpCode('');
                setOtpReqId('');
                setInfo('');
                setError('');
                setResendTimer(0);
              }}
              style={styles.backBtn}
            >
              ← Change mobile number
            </button>
          )}
        </form>
          </div>
        </div>
      </div>
    );
  }

const styles = {
  container: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: '100vh',
    background:
      'radial-gradient(ellipse at 20% 10%, #e8f5e9 0%, transparent 45%), radial-gradient(ellipse at 80% 90%, #e3f2fd 0%, transparent 40%), #f0f4f2',
    padding: 20,
  },
  authBox: {
    width: '100%',
    maxWidth: 420,
    borderRadius: 'var(--radius-lg)',
    padding: '40px 30px',
    boxShadow: 'var(--shadow-lg)',
    textAlign: 'center',
  },
  brandMark: {
    width: 52,
    height: 52,
    margin: '0 auto 14px',
    borderRadius: 14,
    background: 'linear-gradient(135deg, #43a047 0%, #2e7d32 100%)',
    color: '#fff',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: 24,
    fontWeight: 900,
  },
  title: { fontSize: 24, fontWeight: 800, color: 'var(--text-main)', marginBottom: 8 },
  subtitle: {
    fontSize: 13,
    color: 'var(--text-muted)',
    marginBottom: 28,
    lineHeight: 1.45,
  },
  errorAlert: {
    background: '#ffebee',
    color: 'var(--danger-color)',
    padding: 12,
    borderRadius: 'var(--radius-sm)',
    fontSize: 13,
    marginBottom: 16,
    border: '1px solid #ffcdd2',
    textAlign: 'left',
  },
  infoAlert: {
    background: '#e3f2fd',
    color: '#1565c0',
    padding: 12,
    borderRadius: 'var(--radius-sm)',
    fontSize: 13,
    marginBottom: 16,
    border: '1px solid #bbdefb',
    textAlign: 'left',
  },
  tabContainer: {
    display: 'flex',
    borderBottom: '1px solid var(--border-color)',
    marginBottom: 16,
  },
  tab: {
    flex: 1,
    padding: 12,
    background: 'none',
    fontSize: 14,
    fontWeight: 700,
  },
  subTabs: {
    display: 'flex',
    gap: 8,
    marginBottom: 20,
    background: 'rgba(0,0,0,0.03)',
    padding: 4,
    borderRadius: 10,
  },
  subTab: {
    flex: 1,
    padding: '10px 12px',
    borderRadius: 8,
    fontSize: 13,
    fontWeight: 700,
  },
  form: { display: 'flex', flexDirection: 'column', textAlign: 'left' },
  field: { marginBottom: 16 },
  label: {
    display: 'block',
    fontSize: 12,
    fontWeight: 700,
    color: 'var(--text-muted)',
    marginBottom: 8,
    textTransform: 'uppercase',
  },
  submitBtn: {
    background: '#0c831f',
    color: '#fff',
    borderRadius: 10,
    padding: 12,
    fontSize: 15,
    fontWeight: 700,
    marginTop: 8,
    boxShadow: '0 4px 12px rgba(12, 131, 31, 0.25)',
  },
  linkBtn: {
    background: 'transparent',
    color: '#0c831f',
    fontSize: 13,
    marginTop: 14,
    fontWeight: 600,
    padding: 0,
  },
  backBtn: {
    background: 'transparent',
    color: 'var(--text-muted)',
    fontSize: 13,
    marginTop: 14,
    textDecoration: 'underline',
  },
  hint: {
    marginTop: 16,
    fontSize: 11,
    color: 'var(--text-muted)',
    lineHeight: 1.5,
  },
};

