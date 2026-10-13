import React, { useEffect, useState, useMemo } from 'react';
import { supabase } from '../supabase';
import { NOTIFICATION_API_URL } from '../config';
import { PageHead, Stat, Empty } from '../components/ui';

export default function NotificationsPage() {
  const [activeTab, setActiveTab] = useState('broadcast'); // broadcast | direct | orders | logs
  const [serverStatus, setServerStatus] = useState({
    loading: true,
    firebaseReady: false,
    registeredDevices: 0,
    projectId: 'sabzee-wala',
  });

  // Broadcast state
  const [broadcastForm, setBroadcastForm] = useState({
    title: 'Fresh Veggies Just Arrived! 🥦',
    body: 'Farm fresh coriander, spinach, tomatoes and more are in stock. Order now for express delivery!',
    screen: 'home',
  });
  const [broadcastSending, setBroadcastSending] = useState(false);
  const [broadcastResult, setBroadcastResult] = useState(null);

  // Direct notification state
  const [customers, setCustomers] = useState([]);
  const [selectedCustomer, setSelectedCustomer] = useState(null);
  const [directSearch, setDirectSearch] = useState('');
  const [directForm, setDirectForm] = useState({
    title: 'Special Offer For You! 🎁',
    body: 'We miss you at SabzeeWala! Use code SABZEE50 for ₹50 off on your next fresh grocery order.',
    screen: 'home',
  });
  const [directSending, setDirectSending] = useState(false);
  const [directResult, setDirectResult] = useState(null);

  // Logs state
  const [logs, setLogs] = useState([]);
  const [loadingLogs, setLoadingLogs] = useState(false);

  // Quick Preset Templates
  const templates = [
    {
      label: '🥭 Fresh Fruits 20% Off',
      title: 'Sweet Mangoes & Fresh Fruits 20% Off! 🥭',
      body: 'Alfonso mangoes, sweet apples, and fresh bananas just arrived. Flat 20% discount today!',
      screen: 'home',
    },
    {
      label: '🥬 Fresh Morning Harvest',
      title: 'Morning Harvest Just In! 🥬',
      body: 'Directly sourced organic leafy greens and crisp vegetables ready for your kitchen.',
      screen: 'home',
    },
    {
      label: '⚡ Flash Sale ₹50 Off',
      title: 'Flash Sale: Flat ₹50 OFF! ⚡',
      body: 'Get ₹50 off on orders above ₹199. Limited to the first 50 shoppers today!',
      screen: 'home',
    },
    {
      label: '🛵 Free Delivery Alert',
      title: 'Free Express Delivery Today! 🛵',
      body: 'Enjoy zero delivery fee on all orders today. No minimum cart value required!',
      screen: 'home',
    },
  ];

  const [backendUrl, setBackendUrl] = useState(() => {
    return (
      (typeof window !== 'undefined' && localStorage.getItem('sabzee_backend_url')) ||
      NOTIFICATION_API_URL ||
      'http://localhost:5000'
    );
  });
  const [showUrlConfig, setShowUrlConfig] = useState(false);
  const [urlMessage, setUrlMessage] = useState('');

  // Fetch Server status and customer tokens
  const checkStatus = async (targetUrl = backendUrl) => {
    const url = (targetUrl || 'http://localhost:5000').replace(/\/+$/, '');
    try {
      setServerStatus((prev) => ({ ...prev, loading: true }));
      const res = await fetch(`${url}/api/notifications/status`);
      const contentType = res.headers.get('content-type') || '';
      if (res.ok && contentType.includes('application/json')) {
        const data = await res.json();
        setServerStatus({
          loading: false,
          firebaseReady: Boolean(data.firebaseReady),
          registeredDevices: data.registeredDeviceCount || 0,
          projectId: data.projectId || 'sabzee-wala',
        });
        localStorage.setItem('sabzee_backend_url', url);
        setUrlMessage('Connected successfully to ' + url);
        return;
      }
      throw new Error('Received non-JSON response from server');
    } catch (err) {
      const { count } = await supabase
        .from('users')
        .select('id', { count: 'exact', head: true })
        .not('fcm_token', 'is', null);

      setServerStatus({
        loading: false,
        firebaseReady: false,
        registeredDevices: count || 0,
        projectId: 'sabzee-wala',
      });
      setUrlMessage('Unable to reach backend at ' + url);
    }
  };

  // Load customers for direct messaging
  const loadCustomers = async () => {
    const { data } = await supabase
      .from('users')
      .select('id, full_name, mobile, fcm_token, last_active_time')
      .order('last_active_time', { ascending: false })
      .limit(100);

    setCustomers(data || []);
  };

  // Load audit logs
  const loadLogs = async () => {
    setLoadingLogs(true);
    const { data } = await supabase
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(50);

    setLogs(data || []);
    setLoadingLogs(false);
  };

  useEffect(() => {
    checkStatus();
    loadCustomers();
    loadLogs();
  }, []);

  // Filter customers for dropdown
  const filteredCustomers = useMemo(() => {
    const q = directSearch.toLowerCase().trim();
    if (!q) return customers.slice(0, 8);
    return customers.filter(
      (c) =>
        (c.full_name && c.full_name.toLowerCase().includes(q)) ||
        (c.mobile && c.mobile.includes(q)) ||
        (c.id && c.id.includes(q))
    );
  }, [customers, directSearch]);

  // Send Broadcast
  const handleSendBroadcast = async (e) => {
    e.preventDefault();
    if (!broadcastForm.title || !broadcastForm.body) return;

    if (!window.confirm(`Are you sure you want to broadcast this notification to all ${serverStatus.registeredDevices} registered devices?`)) {
      return;
    }

    setBroadcastSending(true);
    setBroadcastResult(null);

    const base = (backendUrl || NOTIFICATION_API_URL || 'http://localhost:5000').replace(/\/+$/, '');
    try {
      const res = await fetch(`${base}/api/notifications/broadcast`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(broadcastForm),
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setBroadcastResult({
          type: 'success',
          msg: `Successfully delivered to ${data.successCount} devices (${data.failureCount} failed out of ${data.totalTargeted}).`,
        });
        loadLogs();
      } else {
        setBroadcastResult({
          type: 'error',
          msg: data.error || data.message || 'Failed to dispatch broadcast.',
        });
      }
    } catch (err) {
      setBroadcastResult({
        type: 'error',
        msg: `Connection error: ${err.message}. Ensure backend is running and reachable.`,
      });
    } finally {
      setBroadcastSending(false);
    }
  };

  // Send Direct Message
  const handleSendDirect = async (e) => {
    e.preventDefault();
    if (!selectedCustomer) {
      alert('Please select a customer first.');
      return;
    }

    setDirectSending(true);
    setDirectResult(null);

    const base = (backendUrl || NOTIFICATION_API_URL || 'http://localhost:5000').replace(/\/+$/, '');
    try {
      const res = await fetch(`${base}/api/notifications/send-to-user`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: selectedCustomer.id,
          phone: selectedCustomer.mobile || selectedCustomer.id,
          title: directForm.title,
          body: directForm.body,
          screen: directForm.screen,
        }),
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setDirectResult({
          type: 'success',
          msg: `Push notification sent to ${selectedCustomer.full_name || selectedCustomer.mobile || selectedCustomer.id}!`,
        });
        loadLogs();
      } else {
        setDirectResult({
          type: 'error',
          msg: data.error || data.message || 'Failed to send notification.',
        });
      }
    } catch (err) {
      setDirectResult({
        type: 'error',
        msg: `Connection error: ${err.message}. Ensure backend server is active.`,
      });
    } finally {
      setDirectSending(false);
    }
  };

  return (
    <div>
      <PageHead
        title="Push Notifications Hub"
        subtitle="Firebase Cloud Messaging (FCM) control center · Broadcast offers & automated order alerts"
        actions={
          <button type="button" className="btn btn-secondary btn-sm" onClick={() => checkStatus()}>
            🔄 Refresh Status
          </button>
        }
      />

      {/* Top Status & Metrics Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 14, marginBottom: 16 }}>
        <Stat
          label="FCM Server Status"
          value={
            serverStatus.loading ? 'Checking...' : serverStatus.firebaseReady ? '🟢 Online & Ready' : '🔴 Server Offline'
          }
          tone={serverStatus.firebaseReady ? 'green' : 'red'}
        />
        <Stat
          label="Firebase Project"
          value={serverStatus.projectId}
          tone="blue"
        />
        <Stat
          label="Registered Devices with Token"
          value={serverStatus.registeredDevices}
          tone="gold"
        />
        <Stat
          label="Automated Store Triggers"
          value="4 Triggers Active"
          tone="green"
        />
      </div>

      {/* Backend Server Connection Bar */}
      <div
        style={{
          padding: '12px 16px',
          borderRadius: 12,
          marginBottom: 18,
          background: serverStatus.firebaseReady ? 'rgba(46, 125, 50, 0.08)' : 'rgba(239, 83, 80, 0.08)',
          border: `1px solid ${serverStatus.firebaseReady ? 'rgba(46, 125, 50, 0.3)' : 'rgba(239, 83, 80, 0.3)'}`,
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 260 }}>
          <span style={{ fontSize: 20 }}>{serverStatus.firebaseReady ? '🟢' : '🔴'}</span>
          <div>
            <div style={{ fontWeight: 700, fontSize: 13 }}>
              {serverStatus.firebaseReady ? 'FCM Backend Server is Connected' : 'Cannot reach backend at ' + backendUrl}
            </div>
            <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
              Target: <code>{backendUrl}</code>
              {urlMessage && ` · ${urlMessage}`}
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          {showUrlConfig ? (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <input
                type="text"
                placeholder="http://localhost:5000"
                value={backendUrl}
                onChange={(e) => setBackendUrl(e.target.value)}
                style={{ width: 230, padding: '6px 10px', fontSize: 13 }}
              />
              <button
                type="button"
                className="btn btn-primary btn-sm"
                onClick={() => {
                  checkStatus(backendUrl);
                  setShowUrlConfig(false);
                }}
              >
                Save & Test
              </button>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={() => setShowUrlConfig(false)}
              >
                Cancel
              </button>
            </div>
          ) : (
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                type="button"
                className="btn btn-secondary btn-sm"
                onClick={() => checkStatus(backendUrl)}
              >
                🔌 Test Connection
              </button>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={() => setShowUrlConfig(true)}
              >
                ⚙️ Change URL
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Navigation Tabs */}
      <div style={{ display: 'flex', gap: 8, borderBottom: '2px solid var(--border)', marginBottom: 20 }}>
        <button
          type="button"
          className={`btn ${activeTab === 'broadcast' ? 'btn-primary' : 'btn-ghost'}`}
          onClick={() => setActiveTab('broadcast')}
        >
          📣 Broadcast to All
        </button>
        <button
          type="button"
          className={`btn ${activeTab === 'direct' ? 'btn-primary' : 'btn-ghost'}`}
          onClick={() => setActiveTab('direct')}
        >
          🎯 Single Customer
        </button>
        <button
          type="button"
          className={`btn ${activeTab === 'orders' ? 'btn-primary' : 'btn-ghost'}`}
          onClick={() => setActiveTab('orders')}
        >
          🛵 Order Status Automation
        </button>
        <button
          type="button"
          className={`btn ${activeTab === 'logs' ? 'btn-primary' : 'btn-ghost'}`}
          onClick={() => {
            setActiveTab('logs');
            loadLogs();
          }}
        >
          📜 Sent Logs
        </button>
      </div>

      {/* TAB 1: BROADCAST CAMPAIGN */}
      {activeTab === 'broadcast' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'minmax(350px, 1.2fr) minmax(280px, 0.8fr)', gap: 24, alignItems: 'start' }}>
          {/* Left Form */}
          <div className="sz-card" style={{ padding: 20 }}>
            <h3 style={{ marginTop: 0, marginBottom: 12 }}>Create Promotional Broadcast</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: 13, marginBottom: 16 }}>
              Sends a push notification to all customers currently registered in your SabzeeWala mobile app.
            </p>

            {/* Quick Templates */}
            <div style={{ marginBottom: 18 }}>
              <label style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-muted)', display: 'block', marginBottom: 8 }}>
                QUICK OFFER TEMPLATES (CLICK TO FILL)
              </label>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {templates.map((tpl, i) => (
                  <button
                    key={i}
                    type="button"
                    className="btn btn-secondary btn-sm"
                    style={{ fontSize: 12 }}
                    onClick={() => {
                      setBroadcastForm({
                        title: tpl.title,
                        body: tpl.body,
                        screen: tpl.screen,
                      });
                    }}
                  >
                    {tpl.label}
                  </button>
                ))}
              </div>
            </div>

            <form onSubmit={handleSendBroadcast}>
              <div className="sz-field" style={{ marginBottom: 14 }}>
                <label>Notification Title</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Fresh Mangoes & Veggies 20% Off! 🥭"
                  value={broadcastForm.title}
                  onChange={(e) => setBroadcastForm({ ...broadcastForm, title: e.target.value })}
                />
              </div>

              <div className="sz-field" style={{ marginBottom: 14 }}>
                <label>Notification Body Message</label>
                <textarea
                  rows={3}
                  required
                  placeholder="e.g. Farm fresh coriander, spinach, and apples just arrived..."
                  value={broadcastForm.body}
                  onChange={(e) => setBroadcastForm({ ...broadcastForm, body: e.target.value })}
                />
              </div>

              <div className="sz-field" style={{ marginBottom: 20 }}>
                <label>When Customer Taps Notification, Open:</label>
                <select
                  value={broadcastForm.screen}
                  onChange={(e) => setBroadcastForm({ ...broadcastForm, screen: e.target.value })}
                >
                  <option value="home">Home Page (Catalog & Deals)</option>
                  <option value="orders">Orders Screen (Active Deliveries)</option>
                </select>
              </div>

              {broadcastResult && (
                <div
                  className={`sz-alert ${broadcastResult.type === 'success' ? 'ok' : 'warn'}`}
                  style={{ marginBottom: 14 }}
                >
                  {broadcastResult.msg}
                </div>
              )}

              <button
                type="submit"
                className="btn btn-primary"
                disabled={broadcastSending}
                style={{ width: '100%', justifyContent: 'center', height: 42 }}
              >
                {broadcastSending ? 'Sending to all devices...' : `🚀 Send Broadcast to ${serverStatus.registeredDevices} Customer(s)`}
              </button>
            </form>
          </div>

          {/* Right: Live Smartphone Preview */}
          <div className="sz-card" style={{ padding: 20 }}>
            <h4 style={{ marginTop: 0, marginBottom: 8 }}>Phone Notification Preview</h4>
            <p style={{ color: 'var(--text-muted)', fontSize: 12, marginBottom: 16 }}>
              How your notification appears on customer Android screens:
            </p>

            <div
              style={{
                background: '#1A1C1E',
                color: '#fff',
                borderRadius: 18,
                padding: '16px 14px',
                boxShadow: '0 8px 24px rgba(0,0,0,0.3)',
                fontFamily: 'system-ui, -apple-system, sans-serif',
              }}
            >
              {/* Fake Android Status bar */}
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: '#9E9E9E', marginBottom: 12 }}>
                <span>10:30 AM</span>
                <span>📶 🔋 98%</span>
              </div>

              {/* Notification Banner Box */}
              <div
                style={{
                  background: '#2B2D30',
                  borderRadius: 14,
                  padding: 12,
                  border: '1px solid #3E4246',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                  <span style={{ fontSize: 16 }}>🥬</span>
                  <span style={{ fontSize: 12, fontWeight: 700, color: '#81C784' }}>SabzeeWala</span>
                  <span style={{ fontSize: 10, color: '#9E9E9E', marginLeft: 'auto' }}>just now</span>
                </div>
                <div style={{ fontWeight: 700, fontSize: 14, color: '#FFFFFF', marginBottom: 3 }}>
                  {broadcastForm.title || 'Notification Title'}
                </div>
                <div style={{ fontSize: 12, color: '#CFD8DC', lineHeight: 1.4 }}>
                  {broadcastForm.body || 'Your message will appear here for customers...'}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 2: DIRECT SINGLE CUSTOMER NOTIFICATION */}
      {activeTab === 'direct' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'minmax(350px, 1fr) minmax(320px, 1fr)', gap: 24 }}>
          {/* Customer Selection Card */}
          <div className="sz-card" style={{ padding: 20 }}>
            <h3 style={{ marginTop: 0, marginBottom: 8 }}>1. Select Customer</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: 13, marginBottom: 12 }}>
              Search customer by name or mobile number:
            </p>

            <input
              type="text"
              placeholder="Search by name or phone (e.g. 98765...)"
              value={directSearch}
              onChange={(e) => setDirectSearch(e.target.value)}
              style={{ width: '100%', marginBottom: 12 }}
            />

            <div style={{ maxHeight: 320, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 6 }}>
              {filteredCustomers.length === 0 ? (
                <Empty text="No matching customers found" />
              ) : (
                filteredCustomers.map((c) => {
                  const isSelected = selectedCustomer?.id === c.id;
                  const hasToken = Boolean(c.fcm_token);
                  return (
                    <div
                      key={c.id}
                      onClick={() => setSelectedCustomer(c)}
                      style={{
                        padding: '10px 12px',
                        borderRadius: 8,
                        cursor: 'pointer',
                        border: isSelected ? '2px solid var(--primary)' : '1px solid var(--border)',
                        background: isSelected ? 'var(--primary-subtle, #E8F5E9)' : 'transparent',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 13 }}>
                          {c.full_name || 'Guest User'}
                        </div>
                        <div style={{ color: 'var(--text-muted)', fontSize: 11 }}>
                          📱 {c.mobile || c.id}
                        </div>
                      </div>
                      <span
                        className={`badge ${hasToken ? 'badge-ok' : 'badge-warn'}`}
                        style={{ fontSize: 10 }}
                      >
                        {hasToken ? 'FCM Ready' : 'No Token'}
                      </span>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* Direct Message Form */}
          <div className="sz-card" style={{ padding: 20 }}>
            <h3 style={{ marginTop: 0, marginBottom: 8 }}>2. Compose Direct Alert</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: 13, marginBottom: 16 }}>
              Target:{' '}
              <strong>
                {selectedCustomer
                  ? `${selectedCustomer.full_name || 'User'} (${selectedCustomer.mobile || selectedCustomer.id})`
                  : 'Please pick a customer from the left list'}
              </strong>
            </p>

            <form onSubmit={handleSendDirect}>
              <div className="sz-field" style={{ marginBottom: 14 }}>
                <label>Title</label>
                <input
                  type="text"
                  required
                  value={directForm.title}
                  onChange={(e) => setDirectForm({ ...directForm, title: e.target.value })}
                />
              </div>

              <div className="sz-field" style={{ marginBottom: 14 }}>
                <label>Message</label>
                <textarea
                  rows={3}
                  required
                  value={directForm.body}
                  onChange={(e) => setDirectForm({ ...directForm, body: e.target.value })}
                />
              </div>

              {directResult && (
                <div
                  className={`sz-alert ${directResult.type === 'success' ? 'ok' : 'warn'}`}
                  style={{ marginBottom: 14 }}
                >
                  {directResult.msg}
                </div>
              )}

              <button
                type="submit"
                className="btn btn-primary"
                disabled={directSending || !selectedCustomer}
                style={{ width: '100%', justifyContent: 'center', height: 42 }}
              >
                {directSending ? 'Sending to Customer...' : 'Send Direct Push Notification'}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* TAB 3: STORE ORDER NOTIFICATION AUTOMATION */}
      {activeTab === 'orders' && (
        <div className="sz-card" style={{ padding: 24 }}>
          <h3 style={{ marginTop: 0, marginBottom: 8 }}>Automatic Store Order Notifications</h3>
          <p style={{ color: 'var(--text-muted)', fontSize: 13, marginBottom: 20 }}>
            Whenever you change order status in the <strong>Orders</strong> screen, a push notification is automatically
            dispatched to the customer's phone:
          </p>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 16 }}>
            <div style={{ padding: 16, borderRadius: 10, background: '#E8F5E9', border: '1px solid #A5D6A7' }}>
              <div style={{ fontWeight: 800, color: '#2E7D32', marginBottom: 4 }}>🥕 1. Order Confirmed</div>
              <div style={{ fontSize: 13, color: '#1B5E20' }}>
                <em>"Your Sabzee order has been confirmed. Fresh veggies are being packed right now!"</em>
              </div>
            </div>

            <div style={{ padding: 16, borderRadius: 10, background: '#E1F5FE', border: '1px solid #81D4FA' }}>
              <div style={{ fontWeight: 800, color: '#0277BD', marginBottom: 4 }}>🛵 2. Out for Delivery</div>
              <div style={{ fontSize: 13, color: '#01579B' }}>
                <em>"Your order is on its way with [Rider Name]. Stay ready!"</em>
              </div>
            </div>

            <div style={{ padding: 16, borderRadius: 10, background: '#F1F8E9', border: '1px solid #C5E1A5' }}>
              <div style={{ fontWeight: 800, color: '#33691E', marginBottom: 4 }}>🥗 3. Order Delivered</div>
              <div style={{ fontSize: 13, color: '#1B5E20' }}>
                <em>"Your fresh items have been delivered safely. Thank you for shopping with SabzeeWala!"</em>
              </div>
            </div>

            <div style={{ padding: 16, borderRadius: 10, background: '#FFEBEE', border: '1px solid #EF9A9A' }}>
              <div style={{ fontWeight: 800, color: '#C62828', marginBottom: 4 }}>❌ 4. Order Cancelled</div>
              <div style={{ fontSize: 13, color: '#B71C1C' }}>
                <em>"Your order was cancelled. Refund processed to your wallet balance."</em>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 4: AUDIT LOGS */}
      {activeTab === 'logs' && (
        <div className="sz-card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <h3 style={{ margin: 0 }}>Sent Notification History</h3>
            <button type="button" className="btn btn-secondary btn-sm" onClick={loadLogs}>
              Refresh Logs
            </button>
          </div>

          {loadingLogs ? (
            <p>Loading history...</p>
          ) : logs.length === 0 ? (
            <Empty text="No notifications logged yet. Send your first broadcast!" />
          ) : (
            <table className="sz-table" style={{ width: '100%' }}>
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Body</th>
                  <th>Type</th>
                  <th>Recipients</th>
                  <th>Sent At</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => (
                  <tr key={log.id}>
                    <td style={{ fontWeight: 600 }}>{log.title}</td>
                    <td style={{ maxWidth: 300, fontSize: 12 }}>{log.body}</td>
                    <td>
                      <span className={`badge ${log.type === 'broadcast' ? 'badge-info' : 'badge-ok'}`}>
                        {log.type}
                      </span>
                    </td>
                    <td>{log.recipients_count || (log.user_id ? `User: ${log.user_id}` : 1)}</td>
                    <td style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                      {new Date(log.created_at).toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}
