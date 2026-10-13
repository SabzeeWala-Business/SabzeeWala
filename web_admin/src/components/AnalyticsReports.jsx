import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '../supabase';
import { orderGrandTotal, normalizePaymentMethod } from '../config';

export default function AnalyticsReports() {
  const [loading, setLoading] = useState(false);
  const [orders, setOrders] = useState([]);
  const [period, setPeriod] = useState('week'); // today | week | month | all

  useEffect(() => {
    fetchAnalytics();
  }, []);

  const fetchAnalytics = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .order('created_at', { ascending: false });
      if (error) throw error;
      setOrders(data || []);
    } catch (err) {
      console.error('Failed to load analytics:', err);
    } finally {
      setLoading(false);
    }
  };

  const inPeriod = (createdAt) => {
    if (period === 'all') return true;
    const d = new Date(createdAt);
    const now = new Date();
    const start = new Date(now);
    start.setHours(0, 0, 0, 0);
    if (period === 'today') return d >= start;
    if (period === 'week') {
      start.setDate(start.getDate() - 6);
      return d >= start;
    }
    if (period === 'month') {
      start.setDate(1);
      return d >= start;
    }
    return true;
  };

  const scoped = useMemo(() => orders.filter((o) => inPeriod(o.created_at)), [orders, period]);

  const stats = useMemo(() => {
    let revenue = 0;
    let deliveredCount = 0;
    let codCount = 0;
    let onlineCount = 0;
    let pendingCount = 0;
    const productCounts = {};
    const daySalesMap = {};

    const daysBack = period === 'today' ? 0 : period === 'month' ? 29 : period === 'all' ? 13 : 6;
    for (let i = daysBack; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const key = d.toISOString().slice(0, 10);
      daySalesMap[key] = {
        label: d.toLocaleDateString(undefined, {
          weekday: daysBack > 7 ? undefined : 'short',
          day: 'numeric',
          month: daysBack > 7 ? 'short' : undefined,
        }),
        amount: 0,
        count: 0,
      };
    }

    scoped.forEach((o) => {
      const grand = orderGrandTotal(o);
      const status = (o.order_status || '').toLowerCase();
      if (status === 'delivered') {
        revenue += grand;
        deliveredCount += 1;
      }
      if (status === 'placed') pendingCount += 1;

      const pay = normalizePaymentMethod(o.payment_method);
      if (pay === 'COD') codCount += 1;
      else if (pay !== '—') onlineCount += 1;

      const orderDate = String(o.created_at || '').slice(0, 10);
      if (daySalesMap[orderDate]) {
        daySalesMap[orderDate].amount += grand;
        daySalesMap[orderDate].count += 1;
      }

      (o.order_items || []).forEach((item) => {
        const name = item.product_name || `SKU ${item.variant_id || ''}`.trim();
        if (!name) return;
        productCounts[name] = (productCounts[name] || 0) + Number(item.quantity || 0);
      });
    });

    const dailySales = Object.keys(daySalesMap).map((key) => ({
      date: key,
      ...daySalesMap[key],
    }));

    const topItems = Object.keys(productCounts)
      .map((name) => ({ name, qty: productCounts[name] }))
      .sort((a, b) => b.qty - a.qty)
      .slice(0, 8);

    return {
      totalRevenue: revenue,
      totalOrders: scoped.length,
      deliveredCount,
      pendingCount,
      averageOrderVal: deliveredCount > 0 ? Math.round(revenue / deliveredCount) : 0,
      codOrdersCount: codCount,
      onlineOrdersCount: onlineCount,
      dailySales,
      topItems,
    };
  }, [scoped, period]);

  const maxSalesVal = Math.max(...stats.dailySales.map((d) => d.amount), 1);

  const exportCsv = () => {
    const rows = [
      ['order_id', 'order_number', 'date', 'status', 'payment_method', 'payment_status', 'total'],
      ...scoped.map((o) => [
        o.id,
        o.order_number || '',
        o.created_at,
        o.order_status || '',
        o.payment_method || '',
        o.payment_status || '',
        orderGrandTotal(o),
      ]),
    ];
    const csv = rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sabzee-sales-${period}-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div style={styles.container}>
      <div style={styles.headerRow}>
        <div>
          <h1 style={styles.title}>Reports & Analytics</h1>
          <p style={styles.subtitle}>Daily, weekly & monthly sales · revenue · top items</p>
        </div>
        <div style={styles.controls}>
          <div style={styles.periodTabs}>
            {[
              ['today', 'Today'],
              ['week', 'Weekly'],
              ['month', 'Monthly'],
              ['all', 'All'],
            ].map(([id, label]) => (
              <button
                key={id}
                type="button"
                onClick={() => setPeriod(id)}
                style={{
                  ...styles.periodBtn,
                  background: period === id ? 'var(--primary)' : 'transparent',
                  color: period === id ? '#fff' : 'var(--text-main)',
                }}
              >
                {label}
              </button>
            ))}
          </div>
          <button type="button" onClick={exportCsv} style={styles.exportBtn}>
            Export CSV
          </button>
          <button type="button" onClick={fetchAnalytics} style={styles.refreshBtn}>
            Refresh
          </button>
        </div>
      </div>

      {loading ? (
        <div style={styles.loading}>Calculating dashboard statistics…</div>
      ) : (
        <div>
          <div style={styles.statsRow}>
            <div style={{ ...styles.card, borderLeft: '5px solid var(--primary)' }}>
              <div style={styles.cardLabel}>Revenue (delivered)</div>
              <div style={styles.cardVal}>₹{stats.totalRevenue.toLocaleString()}</div>
            </div>
            <div style={{ ...styles.card, borderLeft: '5px solid #ff9100' }}>
              <div style={styles.cardLabel}>Orders in period</div>
              <div style={styles.cardVal}>{stats.totalOrders}</div>
            </div>
            <div style={{ ...styles.card, borderLeft: '5px solid var(--accent-color)' }}>
              <div style={styles.cardLabel}>Avg delivered order</div>
              <div style={styles.cardVal}>₹{stats.averageOrderVal}</div>
            </div>
            <div style={{ ...styles.card, borderLeft: '5px solid #ef5350' }}>
              <div style={styles.cardLabel}>Awaiting accept</div>
              <div style={styles.cardVal}>{stats.pendingCount}</div>
            </div>
          </div>

          <div style={styles.dashboardGrid} className="analytics-dashboard-grid">
            <div style={styles.chartBox} className="glass">
              <h3 style={styles.sectionHeader}>
                {period === 'today' ? 'Today' : period === 'month' ? 'Monthly' : period === 'all' ? 'Recent' : 'Weekly'}{' '}
                revenue
              </h3>
              <div style={styles.chartWrapper}>
                {stats.dailySales.map((d, index) => {
                  const percent = Math.min(Math.max((d.amount / maxSalesVal) * 100, d.amount > 0 ? 6 : 2), 100);
                  return (
                    <div key={index} style={styles.chartBarCol} title={`₹${d.amount} · ${d.count} orders`}>
                      <div style={styles.barTooltip}>₹{Math.round(d.amount)}</div>
                      <div style={styles.barTrack}>
                        <div style={{ ...styles.barFill, height: `${percent}%` }} />
                      </div>
                      <div style={styles.barLabel}>{d.label}</div>
                    </div>
                  );
                })}
              </div>
            </div>

            <div style={styles.listCol}>
              <div style={styles.rankBox} className="glass">
                <h3 style={styles.sectionHeader}>Top selling items</h3>
                <div style={styles.rankList}>
                  {stats.topItems.map((item, idx) => (
                    <div key={idx} style={styles.rankItem}>
                      <div style={styles.rankBadge}>{idx + 1}</div>
                      <div style={{ flex: 1, fontWeight: 700 }}>{item.name}</div>
                      <div style={{ color: 'var(--primary)', fontWeight: 800 }}>{item.qty} sold</div>
                    </div>
                  ))}
                  {stats.topItems.length === 0 && (
                    <div style={styles.empty}>No item sales in this period.</div>
                  )}
                </div>
              </div>

              <div style={styles.paymentBox} className="glass">
                <h3 style={styles.sectionHeader}>COD vs online</h3>
                <div style={styles.progressGroup}>
                  <div style={styles.progressLabel}>
                    <span>Cash on Delivery</span>
                    <strong>{stats.codOrdersCount}</strong>
                  </div>
                  <div style={styles.progressBarBg}>
                    <div
                      style={{
                        ...styles.progressBarFill,
                        background: '#5d4037',
                        width: `${
                          stats.totalOrders > 0
                            ? (stats.codOrdersCount / stats.totalOrders) * 100
                            : 0
                        }%`,
                      }}
                    />
                  </div>
                </div>
                <div style={{ ...styles.progressGroup, marginTop: 16 }}>
                  <div style={styles.progressLabel}>
                    <span>Online (UPI / Card)</span>
                    <strong>{stats.onlineOrdersCount}</strong>
                  </div>
                  <div style={styles.progressBarBg}>
                    <div
                      style={{
                        ...styles.progressBarFill,
                        background: 'var(--primary)',
                        width: `${
                          stats.totalOrders > 0
                            ? (stats.onlineOrdersCount / stats.totalOrders) * 100
                            : 0
                        }%`,
                      }}
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

const styles = {
  container: { padding: 30 },
  headerRow: {
    display: 'flex',
    justifyContent: 'space-between',
    gap: 16,
    flexWrap: 'wrap',
    marginBottom: 24,
  },
  title: { fontSize: 22, fontWeight: 800 },
  subtitle: { fontSize: 14, color: 'var(--text-muted)', marginTop: 4 },
  controls: { display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' },
  periodTabs: {
    display: 'flex',
    gap: 4,
    background: 'var(--bg-card)',
    border: '1px solid var(--border-color)',
    borderRadius: 10,
    padding: 4,
  },
  periodBtn: { padding: '8px 12px', borderRadius: 8, fontSize: 12 },
  exportBtn: {
    background: '#e8f5e9',
    color: '#2e7d32',
    padding: '10px 14px',
    borderRadius: 8,
    fontSize: 12,
  },
  refreshBtn: {
    background: 'var(--bg-card)',
    border: '1px solid var(--border-color)',
    color: 'var(--text-main)',
    padding: '10px 14px',
    borderRadius: 8,
    fontSize: 12,
  },
  statsRow: { display: 'flex', gap: 16, marginBottom: 28, flexWrap: 'wrap' },
  card: {
    flex: 1,
    minWidth: 180,
    background: 'var(--bg-card)',
    borderRadius: 12,
    padding: 20,
    boxShadow: 'var(--shadow-sm)',
    border: '1px solid var(--border-color)',
  },
  cardLabel: {
    fontSize: 11,
    fontWeight: 700,
    color: 'var(--text-muted)',
    textTransform: 'uppercase',
    marginBottom: 8,
  },
  cardVal: { fontSize: 26, fontWeight: 800 },
  dashboardGrid: { display: 'grid', gridTemplateColumns: '1.2fr 0.8fr', gap: 24 },
  chartBox: {
    borderRadius: 12,
    padding: 24,
    boxShadow: 'var(--shadow-sm)',
    minHeight: 380,
  },
  sectionHeader: {
    fontSize: 16,
    fontWeight: 800,
    marginBottom: 28,
    borderBottom: '1px solid var(--border-color)',
    paddingBottom: 12,
  },
  chartWrapper: {
    display: 'flex',
    justifyContent: 'space-around',
    alignItems: 'flex-end',
    height: 240,
    gap: 4,
    overflowX: 'auto',
  },
  chartBarCol: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    minWidth: 36,
    position: 'relative',
  },
  barTooltip: {
    position: 'absolute',
    top: -28,
    background: 'var(--text-main)',
    color: 'var(--bg-card)',
    padding: '3px 6px',
    borderRadius: 6,
    fontSize: 10,
    fontWeight: 700,
    whiteSpace: 'nowrap',
  },
  barTrack: {
    width: 22,
    height: 180,
    background: 'rgba(0,0,0,0.03)',
    borderRadius: 12,
    display: 'flex',
    alignItems: 'flex-end',
    overflow: 'hidden',
  },
  barFill: {
    width: '100%',
    background: 'linear-gradient(180deg, var(--primary) 0%, var(--primary-hover) 100%)',
    borderRadius: 12,
    transition: 'height 0.6s ease',
  },
  barLabel: {
    marginTop: 10,
    fontSize: 10,
    fontWeight: 700,
    color: 'var(--text-muted)',
    textAlign: 'center',
  },
  listCol: { display: 'flex', flexDirection: 'column', gap: 24 },
  rankBox: { borderRadius: 12, padding: 24, boxShadow: 'var(--shadow-sm)' },
  rankList: { display: 'flex', flexDirection: 'column', gap: 10 },
  rankItem: {
    display: 'flex',
    alignItems: 'center',
    gap: 14,
    padding: '10px 12px',
    background: 'var(--bg-card)',
    borderRadius: 8,
    border: '1px solid var(--border-color)',
    fontSize: 13,
  },
  rankBadge: {
    width: 24,
    height: 24,
    borderRadius: '50%',
    background: 'rgba(25, 118, 210, 0.1)',
    color: 'var(--primary)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontWeight: 800,
    fontSize: 12,
  },
  paymentBox: { borderRadius: 12, padding: 24, boxShadow: 'var(--shadow-sm)' },
  progressGroup: { display: 'flex', flexDirection: 'column', gap: 8 },
  progressLabel: {
    display: 'flex',
    justifyContent: 'space-between',
    fontSize: 13,
    fontWeight: 700,
  },
  progressBarBg: {
    height: 8,
    background: 'rgba(0,0,0,0.04)',
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressBarFill: { height: '100%', borderRadius: 4 },
  empty: { padding: 20, color: 'var(--text-muted)', fontSize: 13, textAlign: 'center' },
  loading: { padding: 60, textAlign: 'center', color: 'var(--text-muted)', fontWeight: 600 },
};
