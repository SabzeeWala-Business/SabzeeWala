import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../supabase';
import { money, orderTotal, startOfDay, startOfMonth } from '../utils/admin';
import { PageHead, Stat, Empty } from '../components/ui';

export default function Dashboard({ onNavigate }) {
  const [loading, setLoading] = useState(true);
  const [orders, setOrders] = useState([]);
  const [products, setProducts] = useState([]);
  const [variants, setVariants] = useState([]);
  const [riders, setRiders] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [loadError, setLoadError] = useState('');

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      setLoadError('');
      try {
        const [o, p, v, r, s] = await Promise.all([
          supabase.from('orders').select('*, order_items(*)').order('created_at', { ascending: false }),
          supabase.from('products').select('id, name, status, is_organic, is_new_launch, image_url, categories(name)'),
          supabase.from('product_variants').select('*, products(id, name)'),
          supabase.from('delivery_partners').select('*'),
          supabase.from('user_sessions').select('*'),
        ]);
        const err = o.error || p.error || v.error || r.error || s.error;
        if (err) setLoadError(err.message);
        setOrders(o.data || []);
        setProducts(p.data || []);
        setVariants(v.data || []);
        setRiders(r.data || []);
        setSessions(s.data || []);
      } catch (err) {
        setLoadError(err.message || 'Failed to fetch dashboard data');
      }
      setLoading(false);
    };

    fetchData();

    // Subscribe to user sessions table real-time changes
    const ch = supabase
      .channel('live-sessions-dashboard')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'user_sessions' }, async () => {
        const { data } = await supabase.from('user_sessions').select('*');
        if (data) setSessions(data);
      })
      .subscribe();

    return () => {
      supabase.removeChannel(ch);
    };
  }, []);

  const stats = useMemo(() => {
    const today = startOfDay();
    const month = startOfMonth();
    let todayOrders = 0;
    let pending = 0;
    let delivered = 0;
    let revToday = 0;
    let revMonth = 0;

    // 7-day revenue map
    const dayMap = {};
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      dayMap[d.toISOString().slice(0, 10)] = {
        label: d.toLocaleDateString(undefined, { weekday: 'short' }),
        amount: 0,
        count: 0,
      };
    }

    // Top selling product frequency
    const productSales = {};

    orders.forEach((o) => {
      const created = new Date(o.created_at);
      const total = o.total || orderTotal(o);
      const st = String(o.order_status || '').toLowerCase();
      if (created >= today) todayOrders += 1;
      if (st === 'placed' || st === 'pending') pending += 1;
      if (st === 'delivered') {
        delivered += 1;
        if (created >= today) revToday += total;
        if (created >= month) revMonth += total;
      }

      const key = String(o.created_at || '').slice(0, 10);
      if (dayMap[key]) {
        dayMap[key].amount += total;
        dayMap[key].count += 1;
      }

      (o.order_items || []).forEach((it) => {
        const name = it.product_name || 'Produce';
        productSales[name] = (productSales[name] || 0) + (it.quantity || 1);
      });
    });

    let lowStock = 0;
    let outOfStock = 0;
    variants.forEach((v) => {
      const stock = v.stock_total || 0;
      if (stock <= 0) outOfStock += 1;
      else if (stock < 10) lowStock += 1;
    });

    const sortedTopProducts = Object.entries(productSales)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5);

    const activeRiders = riders.filter((r) => r.status === 'available' || r.status === 'on_delivery').length;

    // Derived active online customers in last 5 minutes
    const now = new Date();
    const activeThreshold = 5 * 60 * 1000;
    const onlineUsers = sessions.filter(
      (s) => (now - new Date(s.last_active_at)) < activeThreshold
    ).length;

    return {
      todayOrders,
      pending,
      delivered,
      revToday,
      revMonth,
      dayChart: Object.values(dayMap),
      lowStock,
      outOfStock,
      topProducts: sortedTopProducts,
      activeRiders,
      onlineUsers,
    };
  }, [orders, variants, riders, sessions]);

  const maxChartAmt = Math.max(1, ...stats.dayChart.map((d) => d.amount));

  return (
    <div>
      <PageHead
        title="Live Store Command Center"
        subtitle="Real-time revenue, incoming orders velocity, inventory health, and fleet status"
        actions={
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => onNavigate && onNavigate('notifications')}
            >
              🔔 Send Push Notification
            </button>
            {stats.pending > 0 && (
              <button
                type="button"
                className="btn btn-warn"
                onClick={() => onNavigate && onNavigate('orders')}
              >
                🚨 {stats.pending} Orders Need Packing
              </button>
            )}
          </div>
        }
      />

      {loadError && <div className="sz-alert error">{loadError}</div>}

      {/* KPI Metric Cards */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
          gap: 16,
          marginBottom: 20,
        }}
      >
        <Stat label="Today's Revenue" value={money(stats.revToday)} sub="Completed deliveries" icon="💰" />
        <Stat label="Active Orders Today" value={stats.todayOrders} sub={`${stats.pending} pending packing`} icon="🛍️" />
        <Stat label="Active Customers" value={`${stats.onlineUsers} Online`} sub="Browsing app right now" icon="⚡" />
        <Stat label="Month Revenue" value={money(stats.revMonth)} sub="Gross merchandise value" icon="📈" />
        <Stat label="Live Active Fleet" value={`${stats.activeRiders} Riders`} sub="On shift right now" icon="🛵" />
        <Stat
          label="Low / Out of Stock"
          value={`${stats.lowStock + stats.outOfStock} Items`}
          sub={`${stats.outOfStock} completely empty`}
          icon="⚠️"
        />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 20, marginBottom: 20 }}>
        {/* 7-Day Revenue Velocity Chart */}
        <div style={{ background: '#fff', padding: 20, borderRadius: 14, border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
          <strong style={{ fontSize: 15, color: '#1e293b', display: 'block', marginBottom: 16 }}>
            📊 7-Day Sales & Order Velocity
          </strong>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 14, height: 180, paddingTop: 20 }}>
            {stats.dayChart.map((d, i) => {
              const hPct = Math.max(8, (d.amount / maxChartAmt) * 100);
              return (
                <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                  <span style={{ fontSize: 11, fontWeight: 'bold', color: '#0c831f' }}>
                    {d.amount > 0 ? `₹${d.amount}` : '—'}
                  </span>
                  <div
                    style={{
                      width: '100%',
                      maxWidth: 40,
                      height: `${hPct}%`,
                      background: 'linear-gradient(180deg, #0c831f 0%, #3d9b4a 100%)',
                      borderRadius: '6px 6px 0 0',
                    }}
                  />
                  <span style={{ fontSize: 12, color: '#64748b', fontWeight: 600 }}>{d.label}</span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Top 5 Selling Fresh Produce */}
        <div style={{ background: '#fff', padding: 20, borderRadius: 14, border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
          <strong style={{ fontSize: 15, color: '#1e293b', display: 'block', marginBottom: 14 }}>
            🔥 Fastest Moving Produce
          </strong>
          {stats.topProducts.length === 0 ? (
            <div style={{ fontSize: 12, color: '#94a3b8', textAlign: 'center', padding: '30px 0' }}>
              No sales data recorded yet
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {stats.topProducts.map(([name, qty], idx) => (
                <div
                  key={idx}
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    background: '#f8fafc',
                    padding: '8px 12px',
                    borderRadius: 8,
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontWeight: 800, color: '#0c831f', fontSize: 12 }}>#{idx + 1}</span>
                    <strong style={{ fontSize: 13 }}>{name}</strong>
                  </div>
                  <span className="badge" style={{ background: '#e7f6ea', color: '#0c831f', fontWeight: 'bold' }}>
                    {qty} sold
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Live Recent Orders Feed */}
      <div style={{ background: '#fff', padding: 20, borderRadius: 14, border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
          <strong style={{ fontSize: 15, color: '#1e293b' }}>
            ⚡ Live Incoming Orders Stream
          </strong>
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            onClick={() => onNavigate && onNavigate('orders')}
          >
            View All in Kanban →
          </button>
        </div>

        {orders.length === 0 ? (
          <Empty message="No customer orders received yet" />
        ) : (
          <div className="sz-table-wrap" style={{ border: 'none' }}>
            <table className="sz-table">
              <thead>
                <tr>
                  <th>Order #</th>
                  <th>Placed At</th>
                  <th>Delivery Address</th>
                  <th>Total Amount</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {orders.slice(0, 6).map((o) => (
                  <tr key={o.id}>
                    <td>
                      <strong style={{ color: '#0c831f' }}>{o.order_number || o.id}</strong>
                    </td>
                    <td style={{ fontSize: 12, color: '#64748b' }}>
                      {new Date(o.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </td>
                    <td style={{ fontSize: 12, maxWidth: 260, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {o.delivery_address || 'Customer Location'}
                    </td>
                    <td style={{ fontWeight: 800 }}>{money(o.total || orderTotal(o))}</td>
                    <td>
                      <span
                        className="badge"
                        style={{
                          background:
                            o.order_status === 'delivered'
                              ? '#e7f6ea'
                              : o.order_status === 'packing'
                              ? '#fefce8'
                              : '#eff6ff',
                          color:
                            o.order_status === 'delivered'
                              ? '#0c831f'
                              : o.order_status === 'packing'
                              ? '#ca8a04'
                              : '#2563eb',
                          fontWeight: 'bold',
                        }}
                      >
                        {o.order_status?.toUpperCase() || 'PLACED'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
