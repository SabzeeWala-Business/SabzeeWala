import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '../supabase';
import { orderGrandTotal, normalizePaymentMethod } from '../config';

const STATUS_FLOW = ['placed', 'accepted', 'shipped', 'delivered'];

export default function OrderManager({ onStatusChange }) {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [filterStatus, setFilterStatus] = useState('all');
  const [paymentFilter, setPaymentFilter] = useState('all');
  const [dateFilter, setDateFilter] = useState('today');
  const [search, setSearch] = useState('');

  const playAlertSound = () => {
    try {
      const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = audioCtx.createOscillator();
      const gainNode = audioCtx.createGain();
      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(880, audioCtx.currentTime);
      gainNode.gain.setValueAtTime(0.15, audioCtx.currentTime);
      oscillator.connect(gainNode);
      gainNode.connect(audioCtx.destination);
      oscillator.start();
      oscillator.stop(audioCtx.currentTime + 0.35);
    } catch (_) {}
  };

  useEffect(() => {
    fetchOrders();
    const subscription = supabase
      .channel('orders-realtime-channel')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'orders' }, () => {
        playAlertSound();
        fetchOrders();
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'orders' }, () => {
        fetchOrders();
      })
      .subscribe();

    return () => supabase.removeChannel(subscription);
  }, []);

  const fetchOrders = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*, profiles(name, phone, mobile), order_items(*)')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setOrders(data || []);
      setSelectedOrder((prev) => {
        if (!prev) return prev;
        return (data || []).find((o) => o.id === prev.id) || prev;
      });
    } catch (err) {
      console.error('Failed to fetch orders:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateStatus = async (orderId, newStatus) => {
    try {
      const { error } = await supabase
        .from('orders')
        .update({ order_status: newStatus })
        .eq('id', orderId);
      if (error) throw error;
      await fetchOrders();
      onStatusChange?.();
    } catch (err) {
      alert(err.message || 'Failed to update status.');
    }
  };

  const handlePaymentStatus = async (orderId, paymentStatus) => {
    try {
      const { error } = await supabase
        .from('orders')
        .update({ payment_status: paymentStatus })
        .eq('id', orderId);
      if (error) throw error;
      await fetchOrders();
    } catch (err) {
      alert(err.message || 'Failed to update payment status.');
    }
  };

  const inDateRange = (createdAt) => {
    if (dateFilter === 'all') return true;
    const d = new Date(createdAt);
    const now = new Date();
    const start = new Date(now);
    start.setHours(0, 0, 0, 0);
    if (dateFilter === 'today') return d >= start;
    if (dateFilter === 'week') {
      start.setDate(start.getDate() - 6);
      return d >= start;
    }
    if (dateFilter === 'month') {
      start.setDate(1);
      return d >= start;
    }
    return true;
  };

  const filteredOrders = useMemo(() => {
    return orders.filter((o) => {
      const status = (o.order_status || '').toLowerCase();
      const matchStatus = filterStatus === 'all' || status === filterStatus;
      const pay = normalizePaymentMethod(o.payment_method);
      const matchPayment =
        paymentFilter === 'all' ||
        (paymentFilter === 'cod' && pay === 'COD') ||
        (paymentFilter === 'online' && (pay === 'ONLINE' || pay === 'CARD' || pay === 'UPI'));
      const matchDate = inDateRange(o.created_at);
      const q = search.trim().toLowerCase();
      const customer = o.profiles?.name || '';
      const phone = o.profiles?.phone || o.profiles?.mobile || '';
      const matchSearch =
        !q ||
        String(o.id).toLowerCase().includes(q) ||
        String(o.order_number || '').toLowerCase().includes(q) ||
        customer.toLowerCase().includes(q) ||
        String(phone).includes(q);
      return matchStatus && matchPayment && matchDate && matchSearch;
    });
  }, [orders, filterStatus, paymentFilter, dateFilter, search]);

  const dayStats = useMemo(() => {
    const today = filteredOrders;
    const revenue = today.reduce((s, o) => s + orderGrandTotal(o), 0);
    return { count: today.length, revenue };
  }, [filteredOrders]);

  const customerLabel = (order) =>
    order.profiles?.name || 'Customer';
  const customerPhone = (order) =>
    order.profiles?.phone || order.profiles?.mobile || '—';

  const itemLabel = (item) => {
    if (item.product_name) return item.product_name;
    return `Item ${String(item.variant_id || '').slice(-6) || '—'}`;
  };

  const buildInvoiceHtml = (order) => {
    const items = order.order_items || [];
    const itemsRows = items
      .map(
        (item) => `
      <tr>
        <td>${itemLabel(item)}</td>
        <td>${item.weight || '—'} ${item.unit || ''}</td>
        <td>₹${Number(item.price || 0).toFixed(2)}</td>
        <td>${item.quantity}</td>
        <td>₹${(Number(item.price || 0) * Number(item.quantity || 0)).toFixed(2)}</td>
      </tr>`
      )
      .join('');
    const subtotal = items.reduce(
      (sum, item) => sum + Number(item.price || 0) * Number(item.quantity || 0),
      0
    );
    const ref = order.order_number || `#${String(order.id).slice(-8).toUpperCase()}`;

    return `
      <html>
        <head>
          <title>Invoice ${ref}</title>
          <style>
            body { font-family: 'Segoe UI', sans-serif; padding: 32px; color: #263238; }
            .header { display: flex; justify-content: space-between; border-bottom: 2px solid #e0e0e0; padding-bottom: 16px; }
            .brand { color: #2e7d32; font-size: 22px; font-weight: 800; }
            table { width: 100%; border-collapse: collapse; margin-top: 20px; }
            th, td { border: 1px solid #ddd; padding: 10px; text-align: left; font-size: 13px; }
            th { background: #f5f5f5; }
            .totals { text-align: right; margin-top: 20px; }
            .grand { font-size: 18px; color: #1976d2; font-weight: 800; }
          </style>
        </head>
        <body>
          <div class="header">
            <div>
              <div class="brand">SABZEE</div>
              <div>Fresh groceries · Itemised invoice</div>
            </div>
            <div>
              <h3 style="margin:0">INVOICE</h3>
              <p style="margin:6px 0 0">${ref}</p>
              <p style="margin:4px 0 0">${new Date(order.created_at).toLocaleString()}</p>
            </div>
          </div>
          <div style="margin:20px 0">
            <strong>Bill To</strong>
            <p style="margin:6px 0">${customerLabel(order)}</p>
            <p style="margin:0">${customerPhone(order)}</p>
            <p style="margin:6px 0 0">${order.delivery_address || '—'}</p>
            <p style="margin:6px 0 0">Payment: ${normalizePaymentMethod(order.payment_method)} · ${order.payment_status || 'pending'}</p>
          </div>
          <table>
            <thead>
              <tr><th>Item</th><th>Pack</th><th>Price</th><th>Qty</th><th>Total</th></tr>
            </thead>
            <tbody>${itemsRows}</tbody>
          </table>
          <div class="totals">
            <p>Subtotal: ₹${subtotal.toFixed(2)}</p>
            <p>Delivery / Service: ₹${Number(order.delivery_fee || 0).toFixed(2)}</p>
            <p class="grand">Grand Total: ₹${orderGrandTotal(order).toFixed(2)}</p>
          </div>
        </body>
      </html>`;
  };

  const handlePrintInvoice = () => {
    if (!selectedOrder) return;
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;
    printWindow.document.write(buildInvoiceHtml(selectedOrder));
    printWindow.document.close();
    printWindow.focus();
    setTimeout(() => printWindow.print(), 250);
  };

  const handleShareInvoice = async () => {
    if (!selectedOrder) return;
    const ref = selectedOrder.order_number || String(selectedOrder.id).slice(-6);
    const text = `Sabzee Invoice ${ref}\nCustomer: ${customerLabel(selectedOrder)}\nTotal: ₹${orderGrandTotal(selectedOrder).toFixed(2)}\nPayment: ${normalizePaymentMethod(selectedOrder.payment_method)}\nStatus: ${selectedOrder.order_status}`;
    try {
      if (navigator.share) {
        await navigator.share({ title: `Invoice ${ref}`, text });
      } else {
        await navigator.clipboard.writeText(text);
        alert('Invoice summary copied to clipboard.');
      }
    } catch (_) {}
  };

  const statusStyle = (status) => {
    const s = (status || '').toLowerCase();
    const map = {
      placed: { background: '#fff9c4', color: '#f57f17' },
      accepted: { background: '#e3f2fd', color: '#1565c0' },
      shipped: { background: '#fff3e0', color: '#ef6c00' },
      delivered: { background: '#c8e6c9', color: '#2e7d32' },
      rejected: { background: '#ffebee', color: '#c62828' },
      cancelled: { background: '#eceff1', color: '#37474f' },
    };
    return map[s] || map.placed;
  };

  return (
    <div style={styles.container}>
      <div style={styles.headerRow}>
        <div>
          <h1 style={styles.title}>Order Management</h1>
          <p style={styles.subtitle}>
            Real-time accept/reject · COD vs online · itemised invoices
          </p>
        </div>
        <div style={styles.dayStats}>
          <div>
            <div style={styles.statLabel}>Filtered orders</div>
            <div style={styles.statVal}>{dayStats.count}</div>
          </div>
          <div>
            <div style={styles.statLabel}>Sales total</div>
            <div style={styles.statVal}>₹{dayStats.revenue.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div style={styles.filterRow}>
        <input
          style={{ maxWidth: 220 }}
          placeholder="Search order / customer / phone"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={dateFilter} onChange={(e) => setDateFilter(e.target.value)}>
          <option value="today">Today</option>
          <option value="week">This week</option>
          <option value="month">This month</option>
          <option value="all">All time</option>
        </select>
        <select value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)}>
          <option value="all">All statuses</option>
          {STATUS_FLOW.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
          <option value="rejected">rejected</option>
        </select>
        <select value={paymentFilter} onChange={(e) => setPaymentFilter(e.target.value)}>
          <option value="all">All payments</option>
          <option value="cod">COD only</option>
          <option value="online">Online only</option>
        </select>
      </div>

      <div style={styles.mainGrid} className="orders-main-grid">
        <div style={styles.listSection} className="admin-table-container">
          {loading ? (
            <div style={styles.loading}>Loading orders…</div>
          ) : filteredOrders.length === 0 ? (
            <div style={styles.loading}>No orders match these filters.</div>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Customer</th>
                  <th>When</th>
                  <th>Pay</th>
                  <th>Total</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {filteredOrders.map((o) => (
                  <tr
                    key={o.id}
                    onClick={() => setSelectedOrder(o)}
                    style={{
                      cursor: 'pointer',
                      background:
                        selectedOrder?.id === o.id ? 'rgba(25, 118, 210, 0.06)' : 'transparent',
                    }}
                  >
                    <td style={{ fontWeight: 700 }}>
                      {o.order_number || `#${String(o.id).slice(-6).toUpperCase()}`}
                    </td>
                    <td>{customerLabel(o)}</td>
                    <td>{new Date(o.created_at).toLocaleString()}</td>
                    <td>
                      <span
                        style={{
                          ...styles.badge,
                          background:
                            normalizePaymentMethod(o.payment_method) === 'COD'
                              ? '#efebe9'
                              : '#e3f2fd',
                          color:
                            normalizePaymentMethod(o.payment_method) === 'COD'
                              ? '#5d4037'
                              : '#1565c0',
                        }}
                      >
                        {normalizePaymentMethod(o.payment_method)}
                      </span>
                    </td>
                    <td style={{ fontWeight: 700 }}>₹{orderGrandTotal(o).toFixed(0)}</td>
                    <td>
                      <span style={{ ...styles.statusTag, ...statusStyle(o.order_status) }}>
                        {(o.order_status || '—').toUpperCase()}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        <div style={styles.detailSection} className="glass">
          {selectedOrder ? (
            <div style={styles.detailBox}>
              <div style={styles.detailHeader}>
                <h3>
                  {selectedOrder.order_number ||
                    `#${String(selectedOrder.id).slice(-8).toUpperCase()}`}
                </h3>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button type="button" onClick={handleShareInvoice} style={styles.shareBtn}>
                    Share
                  </button>
                  <button type="button" onClick={handlePrintInvoice} style={styles.invoiceBtn}>
                    Print Invoice
                  </button>
                </div>
              </div>

              <div style={styles.infoBlock}>
                <strong>Customer</strong>
                <p>{customerLabel(selectedOrder)}</p>
                <p>Phone: {customerPhone(selectedOrder)}</p>
                <p>Address: {selectedOrder.delivery_address || '—'}</p>
                <p>
                  Payment: {normalizePaymentMethod(selectedOrder.payment_method)} ·{' '}
                  {(selectedOrder.payment_status || 'pending').toUpperCase()}
                </p>
              </div>

              <div style={styles.infoBlock}>
                <strong>Items</strong>
                <div style={styles.itemsList}>
                  {(selectedOrder.order_items || []).map((item, idx) => (
                    <div key={idx} style={styles.itemRow}>
                      <div>
                        <div style={{ fontWeight: 700 }}>{itemLabel(item)}</div>
                        <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                          {item.weight || ''} {item.unit || ''} × {item.quantity}
                        </div>
                      </div>
                      <div style={{ fontWeight: 700 }}>
                        ₹{(Number(item.price || 0) * Number(item.quantity || 0)).toFixed(0)}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div style={styles.totalsBlock}>
                <div style={styles.totalRow}>
                  <span>Delivery / service</span>
                  <span>₹{Number(selectedOrder.delivery_fee || 0).toFixed(0)}</span>
                </div>
                <div
                  style={{
                    ...styles.totalRow,
                    fontSize: 16,
                    fontWeight: 800,
                    borderTop: '1px solid var(--border-color)',
                    paddingTop: 10,
                  }}
                >
                  <span>Grand total</span>
                  <span style={{ color: 'var(--primary)' }}>
                    ₹{orderGrandTotal(selectedOrder).toFixed(0)}
                  </span>
                </div>
              </div>

              {normalizePaymentMethod(selectedOrder.payment_method) === 'COD' &&
                selectedOrder.order_status === 'delivered' &&
                selectedOrder.payment_status !== 'paid' && (
                  <button
                    type="button"
                    onClick={() => handlePaymentStatus(selectedOrder.id, 'paid')}
                    style={styles.codBtn}
                  >
                    Mark COD Collected
                  </button>
                )}

              <div style={styles.actionsBlock}>
                <strong>Fulfillment</strong>
                <div style={styles.btnGroup}>
                  {(selectedOrder.order_status || '').toLowerCase() === 'placed' && (
                    <>
                      <button
                        type="button"
                        onClick={() => handleUpdateStatus(selectedOrder.id, 'accepted')}
                        style={styles.acceptBtn}
                      >
                        Accept
                      </button>
                      <button
                        type="button"
                        onClick={() => handleUpdateStatus(selectedOrder.id, 'rejected')}
                        style={styles.rejectBtn}
                      >
                        Reject
                      </button>
                    </>
                  )}
                  {(selectedOrder.order_status || '').toLowerCase() === 'accepted' && (
                    <button
                      type="button"
                      onClick={() => handleUpdateStatus(selectedOrder.id, 'shipped')}
                      style={styles.shipBtn}
                    >
                      Mark Shipped
                    </button>
                  )}
                  {(selectedOrder.order_status || '').toLowerCase() === 'shipped' && (
                    <button
                      type="button"
                      onClick={() => handleUpdateStatus(selectedOrder.id, 'delivered')}
                      style={styles.deliverBtn}
                    >
                      Mark Delivered
                    </button>
                  )}
                  {['delivered', 'rejected', 'cancelled'].includes(
                    (selectedOrder.order_status || '').toLowerCase()
                  ) && (
                    <div style={{ fontSize: 13, color: 'var(--text-muted)', fontWeight: 600 }}>
                      Fulfillment complete.
                    </div>
                  )}
                </div>
              </div>
            </div>
          ) : (
            <div style={styles.noOrderSelected}>
              Select an order to accept/reject, update status, or print an invoice.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

const styles = {
  container: { padding: 30 },
  headerRow: {
    display: 'flex',
    justifyContent: 'space-between',
    gap: 20,
    flexWrap: 'wrap',
    marginBottom: 20,
  },
  title: { fontSize: 22, fontWeight: 800 },
  subtitle: { fontSize: 14, color: 'var(--text-muted)', marginTop: 4 },
  dayStats: {
    display: 'flex',
    gap: 24,
    background: 'var(--bg-card)',
    border: '1px solid var(--border-color)',
    borderRadius: 12,
    padding: '12px 20px',
  },
  statLabel: { fontSize: 11, color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' },
  statVal: { fontSize: 20, fontWeight: 800, color: 'var(--primary)' },
  filterRow: {
    display: 'flex',
    gap: 12,
    marginBottom: 22,
    flexWrap: 'wrap',
    background: 'var(--bg-card)',
    padding: 14,
    borderRadius: 12,
    border: '1px solid var(--border-color)',
  },
  mainGrid: {
    display: 'grid',
    gridTemplateColumns: '1.2fr 0.8fr',
    gap: 24,
  },
  listSection: { overflow: 'hidden' },
  badge: { padding: '4px 8px', borderRadius: 6, fontSize: 11, fontWeight: 700 },
  statusTag: {
    padding: '4px 8px',
    borderRadius: 20,
    fontSize: 11,
    fontWeight: 700,
    display: 'inline-block',
  },
  detailSection: {
    borderRadius: 12,
    padding: 24,
    boxShadow: 'var(--shadow-sm)',
    minHeight: 400,
  },
  detailBox: { display: 'flex', flexDirection: 'column', gap: 18 },
  detailHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 10,
    borderBottom: '1px solid var(--border-color)',
    paddingBottom: 12,
    flexWrap: 'wrap',
  },
  invoiceBtn: {
    background: 'var(--primary)',
    color: '#fff',
    padding: '8px 14px',
    borderRadius: 6,
    fontSize: 12,
  },
  shareBtn: {
    background: '#e8f5e9',
    color: '#2e7d32',
    padding: '8px 14px',
    borderRadius: 6,
    fontSize: 12,
  },
  infoBlock: { fontSize: 14, display: 'flex', flexDirection: 'column', gap: 4 },
  itemsList: {
    display: 'flex',
    flexDirection: 'column',
    gap: 10,
    padding: 12,
    borderRadius: 8,
    border: '1px solid var(--border-color)',
    marginTop: 8,
  },
  itemRow: { display: 'flex', justifyContent: 'space-between', fontSize: 13 },
  totalsBlock: { display: 'flex', flexDirection: 'column', gap: 8 },
  totalRow: { display: 'flex', justifyContent: 'space-between', fontSize: 14 },
  actionsBlock: {
    borderTop: '1px solid var(--border-color)',
    paddingTop: 16,
    display: 'flex',
    flexDirection: 'column',
    gap: 12,
  },
  btnGroup: { display: 'flex', gap: 10, flexWrap: 'wrap' },
  acceptBtn: {
    flex: 1,
    background: 'var(--primary)',
    color: '#fff',
    padding: 12,
    borderRadius: 6,
  },
  rejectBtn: {
    background: '#ffebee',
    color: 'var(--danger-color)',
    padding: '12px 18px',
    borderRadius: 6,
  },
  shipBtn: { width: '100%', background: '#fb8c00', color: '#fff', padding: 12, borderRadius: 6 },
  deliverBtn: {
    width: '100%',
    background: 'var(--accent-color)',
    color: '#fff',
    padding: 12,
    borderRadius: 6,
  },
  codBtn: {
    background: '#efebe9',
    color: '#5d4037',
    padding: 12,
    borderRadius: 6,
    fontWeight: 700,
  },
  noOrderSelected: {
    height: '100%',
    minHeight: 280,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: 'var(--text-muted)',
    fontSize: 14,
    textAlign: 'center',
    padding: 40,
  },
  loading: {
    padding: 45,
    textAlign: 'center',
    color: 'var(--text-muted)',
    fontWeight: 600,
  },
};
