import React, { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { PageHead } from '../components/ui';

export default function SettingsPage() {
  const [settings, setSettings] = useState({
    id: 'main_store',
    store_name: 'Sabzee Quick Mart',
    is_store_open: true,
    opening_time: '06:00 AM',
    closing_time: '11:00 PM',
    base_delivery_fee: 30,
    free_delivery_threshold: 139,
    product_handling_fee: 2,
    delivery_radius_km: 10,
    contact_phone: '+91 9876543210',
    support_email: 'support@sabzeewala.com',
    referral_reward_amount: 100,
  });

  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    (async () => {
      setLoading(true);
      const { data } = await supabase.from('store_settings').select('*').limit(1);
      if (data?.[0]) setSettings((s) => ({ ...s, ...data[0] }));
      setLoading(false);
    })();
  }, []);

  const save = async (e) => {
    e.preventDefault();
    setMsg('');
    setError('');

    const payload = {
      id: settings.id || 'main_store',
      store_name: settings.store_name,
      is_store_open: settings.is_store_open,
      opening_time: settings.opening_time,
      closing_time: settings.closing_time,
      base_delivery_fee: Number(settings.base_delivery_fee || 30),
      free_delivery_threshold: Number(settings.free_delivery_threshold || 139),
      product_handling_fee: Number(settings.product_handling_fee || 2),
      delivery_radius_km: Number(settings.delivery_radius_km || 10),
      contact_phone: settings.contact_phone,
      support_email: settings.support_email,
      referral_reward_amount: Number(settings.referral_reward_amount || 100),
      updated_at: new Date().toISOString(),
    };

    const { error: err } = await supabase.from('store_settings').upsert(payload);
    if (err) {
      setError(`Failed to save settings: ${err.message}`);
    } else {
      setMsg('Master Store Settings updated and published to mobile app in real-time!');
    }
  };

  return (
    <div>
      <PageHead
        title="Store Operations & Master App Control"
        subtitle="Control delivery fees, ₹2 product handling charge, free delivery threshold, and store operating hours"
      />

      {error && <div className="sz-alert error">{error}</div>}
      {msg && <div className="sz-alert success">{msg}</div>}

      <form onSubmit={save} style={{ maxWidth: 840, display: 'flex', flexDirection: 'column', gap: 20 }}>
        {/* Store Open / Status Card */}
        <div style={{ background: '#fff', padding: 20, borderRadius: 14, boxShadow: '0 1px 3px rgba(0,0,0,0.05)', border: '1px solid #e2e8f0' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <strong style={{ fontSize: 16, display: 'block' }}>Live Store Status</strong>
              <span style={{ fontSize: 12, color: '#64748b' }}>
                Toggle store online to accept orders on Flutter mobile app
              </span>
            </div>
            <label style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer', fontWeight: 'bold' }}>
              <input
                type="checkbox"
                checked={settings.is_store_open}
                onChange={(e) => setSettings({ ...settings, is_store_open: e.target.checked })}
                style={{ width: 20, height: 20 }}
              />
              <span style={{ color: settings.is_store_open ? '#0c831f' : '#e53935' }}>
                {settings.is_store_open ? '🟢 STORE OPEN' : '🔴 CLOSED / VACATION'}
              </span>
            </label>
          </div>
        </div>

        {/* Dynamic Pricing & Delivery Charges */}
        <div style={{ background: '#fff', padding: 20, borderRadius: 14, boxShadow: '0 1px 3px rgba(0,0,0,0.05)', border: '1px solid #e2e8f0' }}>
          <strong style={{ fontSize: 15, color: '#1e293b', display: 'block', marginBottom: 14 }}>
            💰 App Pricing & Delivery Fee Rules
          </strong>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 14 }}>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                Base Delivery Fee (₹)
              </label>
              <input
                type="number"
                value={settings.base_delivery_fee}
                onChange={(e) => setSettings({ ...settings, base_delivery_fee: e.target.value })}
              />
              <span style={{ fontSize: 11, color: '#888' }}>Standard fee if cart &lt; free limit</span>
            </div>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                Free Delivery Threshold (₹)
              </label>
              <input
                type="number"
                value={settings.free_delivery_threshold}
                onChange={(e) => setSettings({ ...settings, free_delivery_threshold: e.target.value })}
              />
              <span style={{ fontSize: 11, color: '#888' }}>Cart value for 100% FREE delivery</span>
            </div>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                Product Handling Fee (₹)
              </label>
              <input
                type="number"
                value={settings.product_handling_fee}
                onChange={(e) => setSettings({ ...settings, product_handling_fee: e.target.value })}
              />
              <span style={{ fontSize: 11, color: '#888' }}>Flat ₹2 packaging per order</span>
            </div>
          </div>

          <div style={{ marginTop: 14, paddingTop: 14, borderTop: '1px solid #f1f5f9', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                Refer &amp; Earn Wallet Cash (₹)
              </label>
              <input
                type="number"
                value={settings.referral_reward_amount}
                onChange={(e) => setSettings({ ...settings, referral_reward_amount: e.target.value })}
              />
              <span style={{ fontSize: 11, color: '#888' }}>Instant wallet credit for referred users</span>
            </div>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                Delivery Radius (km)
              </label>
              <input
                type="number"
                value={settings.delivery_radius_km}
                onChange={(e) => setSettings({ ...settings, delivery_radius_km: e.target.value })}
              />
              <span style={{ fontSize: 11, color: '#888' }}>Service area around dark store</span>
            </div>
          </div>
        </div>

        {/* Operating Hours & Contact Info */}
        <div style={{ background: '#fff', padding: 20, borderRadius: 14, boxShadow: '0 1px 3px rgba(0,0,0,0.05)', border: '1px solid #e2e8f0' }}>
          <strong style={{ fontSize: 15, color: '#1e293b', display: 'block', marginBottom: 14 }}>
            🕒 Operating Hours & Support Contacts
          </strong>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Opening Time</label>
              <input
                value={settings.opening_time}
                onChange={(e) => setSettings({ ...settings, opening_time: e.target.value })}
                placeholder="06:00 AM"
              />
            </div>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Closing Time</label>
              <input
                value={settings.closing_time}
                onChange={(e) => setSettings({ ...settings, closing_time: e.target.value })}
                placeholder="11:00 PM"
              />
            </div>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Customer Support Helpline</label>
              <input
                value={settings.contact_phone}
                onChange={(e) => setSettings({ ...settings, contact_phone: e.target.value })}
                placeholder="+91 9876543210"
              />
            </div>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Support Email</label>
              <input
                value={settings.support_email}
                onChange={(e) => setSettings({ ...settings, support_email: e.target.value })}
                placeholder="support@sabzeewala.com"
              />
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <button type="submit" className="btn btn-primary" style={{ padding: '12px 28px', fontSize: 15 }}>
            💾 Save & Publish Settings
          </button>
        </div>
      </form>
    </div>
  );
}
