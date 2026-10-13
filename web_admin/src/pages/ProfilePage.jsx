import React, { useEffect, useState } from 'react';
import { supabase, clearOtpSession } from '../supabase';
import { PageHead } from '../components/ui';

export default function ProfilePage({ session, onLogout }) {
  const [profile, setProfile] = useState(null);
  const [name, setName] = useState('');
  const [msg, setMsg] = useState('');
  const [error, setError] = useState('');
  const [pw, setPw] = useState({ a: '', b: '' });

  const user = session?.user;
  const isOtp = user?.user_metadata?.auth_via === 'msg91_otp' || !user?.email;

  useEffect(() => {
    (async () => {
      const id = user?.id || String(user?.phone || '').slice(-10);
      if (!id) return;
      const { data } = await supabase.from('profiles').select('*').eq('id', id).maybeSingle();
      setProfile(data);
      setName(data?.name || user?.user_metadata?.name || '');
    })();
  }, [user]);

  const saveName = async (e) => {
    e.preventDefault();
    setError('');
    setMsg('');
    const id = profile?.id || user?.id || String(user?.phone || '').slice(-10);
    const { error: err } = await supabase.from('profiles').upsert({
      id,
      name,
      email: user?.email || profile?.email || null,
      phone: user?.phone || profile?.phone || null,
      mobile: user?.phone || profile?.mobile || null,
      role: 'admin',
      status: 'active',
    });
    if (err) setError(err.message);
    else setMsg('Profile updated');
  };

  const changePassword = async (e) => {
    e.preventDefault();
    if (pw.a.length < 6 || pw.a !== pw.b) {
      setError('Passwords must match (min 6 chars)');
      return;
    }
    const { error: err } = await supabase.auth.updateUser({ password: pw.a });
    if (err) setError(err.message);
    else {
      setMsg('Password updated');
      setPw({ a: '', b: '' });
    }
  };

  const logout = async () => {
    clearOtpSession();
    await supabase.auth.signOut().catch(() => {});
    onLogout?.();
  };

  return (
    <div>
      <PageHead title="Profile" subtitle="Admin account" />
      {error && <div className="sz-alert error">{error}</div>}
      {msg && <div className="sz-alert ok">{msg}</div>}
      <div className="sz-grid-2">
        <div className="sz-card">
          <div className="sz-card-title">Admin profile</div>
          <form className="sz-form" onSubmit={saveName}>
            <div>
              <label>Name</label>
              <input value={name} onChange={(e) => setName(e.target.value)} required />
            </div>
            <div>
              <label>Email</label>
              <input value={user?.email || profile?.email || '—'} disabled />
            </div>
            <div>
              <label>Phone</label>
              <input value={user?.phone || profile?.phone || profile?.mobile || '—'} disabled />
            </div>
            <div>
              <label>Role</label>
              <input value="admin" disabled />
            </div>
            <button type="submit" className="btn btn-primary">
              Save Profile
            </button>
          </form>
        </div>
        <div className="sz-card">
          <div className="sz-card-title">Security</div>
          {isOtp ? (
            <div className="sz-alert info">Phone OTP login — password change applies to email accounts only.</div>
          ) : (
            <form className="sz-form" onSubmit={changePassword}>
              <div>
                <label>New password</label>
                <input type="password" value={pw.a} onChange={(e) => setPw({ ...pw, a: e.target.value })} />
              </div>
              <div>
                <label>Confirm password</label>
                <input type="password" value={pw.b} onChange={(e) => setPw({ ...pw, b: e.target.value })} />
              </div>
              <button type="submit" className="btn btn-primary">
                Change Password
              </button>
            </form>
          )}
          <div style={{ marginTop: 20 }}>
            <button type="button" className="btn btn-danger" onClick={logout}>
              Logout
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
