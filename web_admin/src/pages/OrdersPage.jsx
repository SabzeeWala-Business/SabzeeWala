import React, { useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import { supabase } from '../supabase';
import { money, orderTotal, statusPill } from '../utils/admin';
import { deductStockForDeliveredOrder } from '../utils/stock';
import { NOTIFICATION_API_URL } from '../config';
import { PageHead, Empty, Modal } from '../components/ui';

export default function OrdersPage() {
  const [orders, setOrders] = useState([]);
  const [riders, setRiders] = useState([]);
  const [viewMode, setViewMode] = useState('kanban'); // 'kanban' | 'table'
  const [tab, setTab] = useState('all');
  const [selected, setSelected] = useState(null);
  const [printOrder, setPrintOrder] = useState(null);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');

  const KANBAN_COLS = [
    { id: 'placed', label: '🆕 Placed / New', color: '#3b82f6', bg: '#eff6ff' },
    { id: 'packing', label: '📦 Packing / Picking', color: '#eab308', bg: '#fefce8' },
    { id: 'out_for_delivery', label: '🛵 Out for Delivery', color: '#8b5cf6', bg: '#f5f3ff' },
    { id: 'delivered', label: '✅ Delivered', color: '#10b981', bg: '#ecfdf5' },
    { id: 'cancelled', label: '❌ Cancelled', color: '#ef4444', bg: '#fef2f2' },
  ];

  const renderPaymentBadge = (method, status) => {
    const m = String(method || '').toUpperCase();
    const isPaid = String(status || '').toLowerCase() === 'paid';
    if (m === 'COD' || m.includes('COD')) {
      return (
        <span className="badge" style={{ background: '#fff7ed', color: '#ea580c', border: '1px solid #ffedd5', fontSize: 10, fontWeight: 700 }}>
          💵 COD {isPaid ? '(COLLECTED)' : '(PENDING)'}
        </span>
      );
    }
    if (m === 'UPI' || m.includes('UPI')) {
      return (
        <span className="badge" style={{ background: '#ecfdf5', color: '#059669', border: '1px solid #a7f3d0', fontSize: 10, fontWeight: 700 }}>
          ⚡ UPI (PAID)
        </span>
      );
    }
    if (m === 'CARD' || m.includes('CARD') || m.includes('DEBIT') || m.includes('CREDIT')) {
      return (
        <span className="badge" style={{ background: '#eff6ff', color: '#2563eb', border: '1px solid #bfdbfe', fontSize: 10, fontWeight: 700 }}>
          💳 CARD (PAID)
        </span>
      );
    }
    return (
      <span className="badge" style={{ background: '#f0fdf4', color: '#16a34a', border: '1px solid #bbf7d0', fontSize: 10, fontWeight: 700 }}>
        🌐 {m || 'ONLINE'} (PAID)
      </span>
    );
  };

  const load = async () => {
    setLoading(true);
    setError('');
    const [ordersRes, usersRes, ridersRes] = await Promise.all([
      supabase.from('orders').select('*, order_items(*)').order('created_at', { ascending: false }),
      supabase.from('users').select('id, full_name, mobile, email'),
      supabase.from('delivery_partners').select('*').order('name'),
    ]);

    if (ordersRes.error) {
      setError(ordersRes.error.message);
      setLoading(false);
      return;
    }

    const ordersData = ordersRes.data || [];
    const usersData = usersRes.data || [];
    const ridersData = ridersRes.data || [];

    const normalized = ordersData.map((o) => {
      const user = usersData.find((u) => String(u.id) === String(o.user_id));
      return {
        ...o,
        customer_name: user?.full_name || 'Valued Customer',
        customer_phone: user?.mobile || o.user_id || 'N/A',
        customer_email: user?.email || '',
      };
    });

    setOrders(normalized);
    setRiders(ridersData);
    setLoading(false);
  };

  useEffect(() => {
    load();
    const ch = supabase
      .channel('admin-orders-live-kanban')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => load())
      .subscribe();
    return () => supabase.removeChannel(ch);
  }, []);

  const filtered = useMemo(() => {
    return orders.filter((o) => {
      const q = search.toLowerCase();
      const matchQ =
        !q ||
        o.id?.toLowerCase().includes(q) ||
        o.order_number?.toLowerCase().includes(q) ||
        o.customer_name?.toLowerCase().includes(q) ||
        o.customer_phone?.toLowerCase().includes(q) ||
        o.delivery_address?.toLowerCase().includes(q);
      const matchT = tab === 'all' || String(o.order_status || '').toLowerCase() === tab;
      return matchQ && matchT;
    });
  }, [orders, search, tab]);

  const updateStatus = async (id, newStatus) => {
    setError('');
    setOk('');
    const order = orders.find((o) => o.id === id);
    if (!order) return;
    
    const prev = String(order.order_status || '').toLowerCase();

    const { error: err } = await supabase.from('orders').update({ order_status: newStatus }).eq('id', id);
    if (err) {
      setError(err.message);
      return;
    }

    let refundMsg = '';
    // 1. Check for ONLINE/WALLET cancellation refunds
    if (newStatus === 'cancelled' && prev !== 'cancelled') {
      const pm = String(order.payment_method || '').toUpperCase();
      const totalAmount = parseFloat(order.total || orderTotal(order)) || 0;
      const customerId = order.user_id;

      if (pm !== 'COD' && customerId) {
        try {
          const { data: userData } = await supabase
            .from('users')
            .select('wallet_balance')
            .eq('id', customerId)
            .maybeSingle();

          const currentBalance = parseFloat(userData?.wallet_balance || 0);
          const nextBalance = currentBalance + totalAmount;

          await supabase.from('users').update({ wallet_balance: nextBalance }).eq('id', customerId);

          await supabase.from('wallet_transactions').insert({
            user_id: customerId,
            amount: totalAmount,
            type: 'refund',
            description: `Refund for Cancelled Order #${order.id}`,
            status: 'completed',
          });
          
          refundMsg = ` ₹${totalAmount} refunded to customer's wallet.`;
        } catch (rErr) {
          console.error("Order cancellation refund failed:", rErr);
        }
      }
    }

    // 2. Sync rider count if order is delivered or cancelled
    if ((newStatus === 'delivered' || newStatus === 'cancelled') && (prev !== 'delivered' && prev !== 'cancelled')) {
      const riderId = order.rider_id;
      if (riderId) {
        try {
          const { data: rData } = await supabase
            .from('delivery_partners')
            .select('active_orders_count')
            .eq('id', riderId)
            .maybeSingle();
          
          if (rData) {
            const nextCount = Math.max(0, (rData.active_orders_count || 1) - 1);
            await supabase.from('delivery_partners').update({
              active_orders_count: nextCount,
              status: nextCount === 0 ? 'available' : 'on_delivery',
            }).eq('id', riderId);
          }
        } catch (rErr) {
          console.error("Rider sync failed:", rErr);
        }
      }
    }

    // Auto deduct store inventory upon successful delivery
    if (newStatus === 'delivered' && prev !== 'delivered') {
      const result = await deductStockForDeliveredOrder(order);
      const lines = (result.deducted || []).map((d) => `${d.sold} sold → ${d.remaining} left`).join(', ');
      setOk(lines ? `Order Delivered! Stock updated: ${lines}${refundMsg}` : `Order Delivered and marked completed.${refundMsg}`);
    } else {
      setOk(`Order ${id} updated to status: ${newStatus}.${refundMsg}`);
    }

    // Trigger automated push notification to customer via FCM backend
    try {
      fetch(`${NOTIFICATION_API_URL}/api/notifications/order-status`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          orderId: id,
          userId: order.user_id,
          newStatus: newStatus,
          riderName: order.rider_name,
          riderPhone: order.rider_phone,
        }),
      }).catch((err) => console.log('FCM order alert dispatch error:', err));
    } catch (_) {}

    load();
  };

  const assignRider = async (orderId, riderId) => {
    const order = orders.find((o) => o.id === orderId);
    const oldRiderId = order?.rider_id;
    const rider = riders.find((r) => r.id === riderId);

    const { error: err } = await supabase.from('orders').update({
      rider_id: riderId || null,
      rider_name: rider?.name || null,
      rider_phone: rider?.phone || null,
    }).eq('id', orderId);

    if (err) {
      setError(err.message);
      return;
    }

    // 1. Decrement old rider count if changed
    if (oldRiderId && oldRiderId !== riderId) {
      try {
        const { data: oldRider } = await supabase
          .from('delivery_partners')
          .select('active_orders_count')
          .eq('id', oldRiderId)
          .maybeSingle();
        if (oldRider) {
          const nextCount = Math.max(0, (oldRider.active_orders_count || 1) - 1);
          await supabase.from('delivery_partners').update({
            active_orders_count: nextCount,
            status: nextCount === 0 ? 'available' : 'on_delivery',
          }).eq('id', oldRiderId);
        }
      } catch (_) {}
    }

    // 2. Increment new rider count and set status
    if (riderId && oldRiderId !== riderId) {
      try {
        const activeCount = (rider?.active_orders_count || 0) + 1;
        await supabase.from('delivery_partners').update({
          active_orders_count: activeCount,
          status: 'on_delivery',
        }).eq('id', riderId);
      } catch (_) {}
    }

    setOk(`Rider ${rider?.name || 'Unassigned'} assigned to Order ${orderId}`);
    load();
  };

  const triggerPrint = async (o) => {
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', o.id)
        .single();
      if (error) {
        console.error("Error fetching latest order details for print:", error);
        setPrintOrder(o);
      } else {
        const { data: userData } = await supabase
          .from('users')
          .select('full_name, mobile, email')
          .eq('id', data.user_id)
          .maybeSingle();

        const merged = {
          ...data,
          customer_name: userData?.full_name || 'Valued Customer',
          customer_phone: userData?.mobile || data.user_id || 'N/A',
          customer_email: userData?.email || '',
        };
        setPrintOrder(merged);
      }
    } catch (e) {
      console.error("Error fetching latest order for print:", e);
      setPrintOrder(o);
    }
  };

  useEffect(() => {
    if (printOrder) {
      const timer = setTimeout(() => {
        window.print();
        setPrintOrder(null);
      }, 400);
      return () => clearTimeout(timer);
    }
  }, [printOrder]);

  return (
    <div>
      <PageHead
        title="Live Orders & Dispatch"
        subtitle="Manage fast-delivery fulfillment, Kanban packing lines, and delivery rider dispatches"
        actions={
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <div style={{ background: '#e2e8f0', borderRadius: 8, padding: 2, display: 'flex' }}>
              <button
                type="button"
                className={`btn btn-sm ${viewMode === 'kanban' ? 'btn-primary' : 'btn-ghost'}`}
                onClick={() => setViewMode('kanban')}
                style={{ padding: '6px 12px' }}
              >
                📋 Kanban Board
              </button>
              <button
                type="button"
                className={`btn btn-sm ${viewMode === 'table' ? 'btn-primary' : 'btn-ghost'}`}
                onClick={() => setViewMode('table')}
                style={{ padding: '6px 12px' }}
              >
                📑 Table List
              </button>
            </div>
            <button type="button" className="btn btn-ghost btn-sm" onClick={load}>
              🔄 Refresh
            </button>
          </div>
        }
      />

      {error && <div className="sz-alert error">{error}</div>}
      {ok && <div className="sz-alert success">{ok}</div>}

      <div className="sz-toolbar" style={{ flexWrap: 'wrap', gap: 10 }}>
        <input
          className="grow"
          placeholder="Search by Order ID, Customer Name, Phone or Address…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ minWidth: 260 }}
        />
        <select value={tab} onChange={(e) => setTab(e.target.value)} style={{ maxWidth: 180 }}>
          <option value="all">All Statuses ({orders.length})</option>
          {KANBAN_COLS.map((col) => {
            const count = orders.filter((o) => (o.order_status || 'placed').toLowerCase() === col.id).length;
            return (
              <option key={col.id} value={col.id}>
                {col.label} ({count})
              </option>
            );
          })}
        </select>
      </div>

      {loading ? (
        <div className="sz-empty">Connecting to live order stream…</div>
      ) : filtered.length === 0 ? (
        <Empty message="No orders match your filter" />
      ) : viewMode === 'kanban' ? (
        /* KANBAN FULFILLMENT BOARD */
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
            gap: 16,
            alignItems: 'start',
            overflowX: 'auto',
            paddingBottom: 20,
          }}
        >
          {KANBAN_COLS.map((col) => {
            const colOrders = filtered.filter((o) => (o.order_status || 'placed').toLowerCase() === col.id);
            return (
              <div
                key={col.id}
                style={{
                  background: '#f8fafc',
                  borderRadius: 14,
                  border: `1px solid #e2e8f0`,
                  padding: 12,
                  minHeight: 450,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 10,
                }}
              >
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    paddingBottom: 8,
                    borderBottom: `2px solid ${col.color}`,
                  }}
                >
                  <strong style={{ fontSize: 13, color: '#1e293b' }}>{col.label}</strong>
                  <span
                    style={{
                      background: col.bg,
                      color: col.color,
                      fontWeight: 800,
                      fontSize: 12,
                      padding: '2px 8px',
                      borderRadius: 12,
                    }}
                  >
                    {colOrders.length}
                  </span>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {colOrders.length === 0 ? (
                    <div style={{ textAlign: 'center', padding: '30px 10px', color: '#94a3b8', fontSize: 12 }}>
                      No orders in this stage
                    </div>
                  ) : (
                    colOrders.map((o) => {
                      const items = o.order_items || [];
                      return (
                        <div
                          key={o.id}
                          style={{
                            background: '#fff',
                            borderRadius: 10,
                            padding: 12,
                            boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
                            border: '1px solid #f1f5f9',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: 8,
                          }}
                        >
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <strong style={{ fontSize: 13, color: '#0c831f' }}>
                              {o.order_number || o.id}
                            </strong>
                            <span style={{ fontSize: 11, color: '#64748b' }}>
                              {new Date(o.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            </span>
                          </div>

                          <div style={{ fontSize: 12 }}>
                            <strong>{o.customer_name}</strong>
                            <div style={{ color: '#64748b', fontSize: 11 }}>📞 +{o.customer_phone}</div>
                            <div
                              style={{
                                color: '#475569',
                                fontSize: 11,
                                whiteSpace: 'nowrap',
                                overflow: 'hidden',
                                textOverflow: 'ellipsis',
                              }}
                            >
                              📍 {o.delivery_address || 'No address provided'}
                            </div>
                          </div>

                          {/* Line items preview */}
                          <div style={{ background: '#f8fafc', padding: '6px 8px', borderRadius: 6, fontSize: 11 }}>
                            <div style={{ fontWeight: 600, color: '#334155', marginBottom: 2 }}>
                              {items.length} items:
                            </div>
                            {items.slice(0, 3).map((it, i) => (
                              <div key={i} style={{ color: '#64748b' }}>
                                • {it.product_name || 'Item'} ({it.weight || 1}{it.unit || 'x'}) × {it.quantity}
                              </div>
                            ))}
                            {items.length > 3 && (
                              <div style={{ color: '#0c831f', fontWeight: 600 }}>+{items.length - 3} more items...</div>
                            )}
                          </div>

                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 4 }}>
                            <div style={{ fontWeight: 800, fontSize: 14, color: '#0f172a' }}>
                              {money(o.total || orderTotal(o))}
                            </div>
                            {renderPaymentBadge(o.payment_method, o.payment_status)}
                          </div>

                          {/* Quick Workflow Action Buttons */}
                          <div style={{ display: 'flex', gap: 6, marginTop: 4, flexWrap: 'wrap' }}>
                            {col.id === 'placed' && (
                              <button
                                type="button"
                                className="btn btn-primary btn-sm grow"
                                onClick={() => updateStatus(o.id, 'packing')}
                              >
                                📦 Start Packing
                              </button>
                            )}
                            {col.id === 'packing' && (
                              <button
                                type="button"
                                className="btn btn-primary btn-sm grow"
                                onClick={() => updateStatus(o.id, 'out_for_delivery')}
                              >
                                🛵 Dispatch Order
                              </button>
                            )}
                            {col.id === 'out_for_delivery' && (
                              <button
                                type="button"
                                className="btn btn-primary btn-sm grow"
                                style={{ background: '#10b981' }}
                                onClick={() => updateStatus(o.id, 'delivered')}
                              >
                                ✅ Mark Delivered
                              </button>
                            )}
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm"
                              onClick={() => triggerPrint(o)}
                              title="Print Slip"
                            >
                              🖨️ Print
                            </button>
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm"
                              onClick={() => setSelected(o)}
                              title="Full Details"
                            >
                              👁️
                            </button>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        /* TABLE LIST VIEW */
        <div className="sz-table-wrap">
          <table className="sz-table">
            <thead>
              <tr>
                <th>Order #</th>
                <th>Time</th>
                <th>Customer</th>
                <th>Delivery Address</th>
                <th>Items</th>
                <th>Total</th>
                <th>Payment</th>
                <th>Rider</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((o) => (
                <tr key={o.id}>
                  <td>
                    <strong style={{ color: '#0c831f' }}>{o.order_number || o.id}</strong>
                  </td>
                  <td style={{ fontSize: 12, color: '#64748b' }}>
                    {new Date(o.created_at).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' })}
                  </td>
                  <td>
                    <strong>{o.customer_name}</strong>
                    <div style={{ fontSize: 11, color: '#64748b' }}>+{o.customer_phone}</div>
                  </td>
                  <td style={{ maxWidth: 200, fontSize: 12 }}>{o.delivery_address || '—'}</td>
                  <td>{(o.order_items || []).length} items</td>
                  <td style={{ fontWeight: 700 }}>{money(o.total || orderTotal(o))}</td>
                  <td>
                    {renderPaymentBadge(o.payment_method, o.payment_status)}
                  </td>
                  <td>
                    <select
                      value={o.rider_id || ''}
                      onChange={(e) => assignRider(o.id, e.target.value)}
                      style={{ fontSize: 11, padding: '4px 8px' }}
                    >
                      <option value="">Unassigned</option>
                      {riders.map((r) => (
                        <option key={r.id} value={r.id}>
                          {r.name} ({r.vehicle_type})
                        </option>
                      ))}
                    </select>
                  </td>
                  <td>
                    <select
                      value={o.order_status || 'placed'}
                      onChange={(e) => updateStatus(o.id, e.target.value)}
                      style={{ fontSize: 12, fontWeight: 'bold' }}
                    >
                      <option value="placed">Placed</option>
                      <option value="packing">Packing</option>
                      <option value="out_for_delivery">Out for Delivery</option>
                      <option value="delivered">Delivered</option>
                      <option value="cancelled">Cancelled</option>
                    </select>
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button type="button" className="btn btn-ghost btn-sm" onClick={() => triggerPrint(o)}>
                        🖨️
                      </button>
                      <button type="button" className="btn btn-ghost btn-sm" onClick={() => setSelected(o)}>
                        Details
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Comprehensive Full-Screen Order Detail & Status Transition Modal */}
      {selected && (
        <Modal
          title={`Order Management: #${selected.order_number || selected.id}`}
          onClose={() => setSelected(null)}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {/* Top Status Banner & Live Action Buttons */}
            <div
              style={{
                background: '#f8fafc',
                padding: 14,
                borderRadius: 12,
                border: '1px solid #e2e8f0',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                flexWrap: 'wrap',
                gap: 10,
              }}
            >
              <div>
                <div style={{ fontSize: 11, color: '#64748b', fontWeight: 600 }}>CURRENT ORDER STAGE</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
                  <span
                    className="badge"
                    style={{
                      fontSize: 13,
                      padding: '4px 12px',
                      background:
                        selected.order_status === 'delivered'
                          ? '#e7f6ea'
                          : selected.order_status === 'out_for_delivery'
                          ? '#f5f3ff'
                          : selected.order_status === 'packing'
                          ? '#fefce8'
                          : selected.order_status === 'cancelled'
                          ? '#fef2f2'
                          : '#eff6ff',
                      color:
                        selected.order_status === 'delivered'
                          ? '#0c831f'
                          : selected.order_status === 'out_for_delivery'
                          ? '#8b5cf6'
                          : selected.order_status === 'packing'
                          ? '#ca8a04'
                          : selected.order_status === 'cancelled'
                          ? '#ef4444'
                          : '#3b82f6',
                      fontWeight: 800,
                    }}
                  >
                    {selected.order_status?.toUpperCase() || 'PLACED'}
                  </span>
                  <span style={{ fontSize: 11, color: '#94a3b8' }}>
                    Placed: {new Date(selected.created_at).toLocaleString()}
                  </span>
                </div>
              </div>

              {/* Stage Transition Action Buttons */}
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                <button
                  type="button"
                  className={`btn btn-sm ${selected.order_status === 'placed' ? 'btn-primary' : 'btn-ghost'}`}
                  style={{ fontSize: 11, padding: '4px 8px' }}
                  onClick={() => updateStatus(selected.id, 'placed')}
                >
                  📥 Booked
                </button>
                <button
                  type="button"
                  className={`btn btn-sm ${selected.order_status === 'packing' ? 'btn-primary' : 'btn-ghost'}`}
                  style={{ fontSize: 11, padding: '4px 8px' }}
                  onClick={() => updateStatus(selected.id, 'packing')}
                >
                  📦 Packing
                </button>
                <button
                  type="button"
                  className={`btn btn-sm ${selected.order_status === 'out_for_delivery' ? 'btn-primary' : 'btn-ghost'}`}
                  style={{ fontSize: 11, padding: '4px 8px' }}
                  onClick={() => updateStatus(selected.id, 'out_for_delivery')}
                >
                  🛵 Dispatch
                </button>
                <button
                  type="button"
                  className={`btn btn-sm ${selected.order_status === 'delivered' ? 'btn-primary' : 'btn-ghost'}`}
                  style={{ fontSize: 11, padding: '4px 8px', background: selected.order_status === 'delivered' ? '#10b981' : undefined }}
                  onClick={() => updateStatus(selected.id, 'delivered')}
                >
                  ✅ Delivered
                </button>
                <button
                  type="button"
                  className="btn btn-danger btn-sm"
                  style={{ fontSize: 11, padding: '4px 8px' }}
                  onClick={() => {
                    if (confirm('Cancel this order?')) updateStatus(selected.id, 'cancelled');
                  }}
                >
                  ❌ Cancel
                </button>
              </div>
            </div>

            {/* Customer, Location & Rider Details */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              {/* Customer Card */}
              <div style={{ background: '#fff', padding: 14, borderRadius: 10, border: '1px solid #e2e8f0' }}>
                <div style={{ fontSize: 11, color: '#64748b', fontWeight: 700, textTransform: 'uppercase', marginBottom: 6 }}>
                  👤 Customer Information
                </div>
                <strong style={{ fontSize: 15, color: '#0f172a' }}>{selected.customer_name}</strong>
                <div style={{ fontSize: 13, color: '#334155', marginTop: 2 }}>
                  📞 <b>+{selected.customer_phone}</b>
                </div>
                {selected.customer_email && (
                  <div style={{ fontSize: 12, color: '#64748b' }}>✉️ {selected.customer_email}</div>
                )}
                <div style={{ marginTop: 8 }}>
                  {renderPaymentBadge(selected.payment_method, selected.payment_status)}
                </div>
              </div>

              {/* Delivery Address & Assigned Rider Card */}
              <div style={{ background: '#fff', padding: 14, borderRadius: 10, border: '1px solid #e2e8f0' }}>
                <div style={{ fontSize: 11, color: '#64748b', fontWeight: 700, textTransform: 'uppercase', marginBottom: 6 }}>
                  📍 Delivery Location & Dispatch
                </div>
                <div style={{ fontSize: 13, color: '#1e293b', lineHeight: 1.4 }}>
                  {selected.delivery_address || 'Customer Delivery Address'}
                </div>
                
                <div style={{ marginTop: 10, paddingTop: 8, borderTop: '1px solid #f1f5f9' }}>
                  <div style={{ fontSize: 11, color: '#64748b', marginBottom: 4 }}>Assigned Delivery Partner:</div>
                  <select
                    value={selected.rider_id || ''}
                    onChange={(e) => assignRider(selected.id, e.target.value)}
                    style={{ fontSize: 12, padding: '4px 8px', fontWeight: 600 }}
                  >
                    <option value="">Choose Rider to Dispatch</option>
                    {riders.map((r) => (
                      <option key={r.id} value={r.id}>
                        🛵 {r.name} (+{r.phone}) - {r.vehicle_type}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </div>

            {/* Packaged Produce Line Items Table */}
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                <strong style={{ fontSize: 14, color: '#1e293b' }}>
                  🛒 Packaged Produce ({selected.order_items?.length || 0} items)
                </strong>
                <span style={{ fontSize: 11, color: '#64748b' }}>Includes fresh sorting guarantee</span>
              </div>

              <div style={{ border: '1px solid #e2e8f0', borderRadius: 10, overflow: 'hidden' }}>
                <table className="sz-table" style={{ margin: 0 }}>
                  <thead>
                    <tr>
                      <th>Product Name</th>
                      <th>Pack Size</th>
                      <th>Unit Price</th>
                      <th style={{ textAlign: 'center' }}>Quantity</th>
                      <th style={{ textAlign: 'right' }}>Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(selected.order_items || []).map((it, i) => (
                      <tr key={i}>
                        <td>
                          <strong style={{ color: '#0f172a' }}>{it.product_name || 'Produce Item'}</strong>
                        </td>
                        <td>
                          <span className="badge" style={{ background: '#f8fafc' }}>
                            {it.weight || 1} {it.unit || 'kg'}
                          </span>
                        </td>
                        <td>₹{it.price || 0}</td>
                        <td style={{ textAlign: 'center', fontWeight: 'bold' }}>× {it.quantity || 1}</td>
                        <td style={{ textAlign: 'right', fontWeight: 'bold', color: '#0c831f' }}>
                          ₹{(it.price || 0) * (it.quantity || 1)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Bill Summary & Print Action Footer */}
            <div
              style={{
                background: '#f8fafc',
                padding: 16,
                borderRadius: 10,
                border: '1px solid #e2e8f0',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                flexWrap: 'wrap',
                gap: 12,
              }}
            >
              <div style={{ display: 'flex', gap: 20, fontSize: 13 }}>
                <div>
                  <span style={{ color: '#64748b' }}>Items Subtotal: </span>
                  <strong>₹{(selected.order_items || []).reduce((acc, it) => acc + (it.price || 0) * (it.quantity || 1), 0)}</strong>
                </div>
                <div>
                  <span style={{ color: '#64748b' }}>Product Handling: </span>
                  <strong>₹2.00</strong>
                </div>
                <div>
                  <span style={{ color: '#64748b' }}>Delivery Fee: </span>
                  <strong>{selected.delivery_fee ? `₹${selected.delivery_fee}` : 'FREE'}</strong>
                </div>
                <div>
                  <span style={{ color: '#64748b' }}>Total Payable: </span>
                  <strong style={{ fontSize: 16, color: '#0c831f' }}>
                    {money(selected.total || orderTotal(selected))}
                  </strong>
                </div>
              </div>

              <div style={{ display: 'flex', gap: 8 }}>
                <button
                  type="button"
                  className="btn btn-primary btn-sm"
                  onClick={() => triggerPrint(selected)}
                  style={{ padding: '8px 16px', fontSize: 13 }}
                >
                  🖨️ Print Tax & Packing Invoice
                </button>
                <button
                  type="button"
                  className="btn btn-ghost btn-sm"
                  onClick={() => setSelected(null)}
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </Modal>
      )}

      {/* Official SabzeeWala Single-Order Thermal & Standard Printable Receipt */}
      {printOrder && createPortal(
        <div id="official-invoice-print">
          <div style={{ textAlign: 'center', marginBottom: 8, borderBottom: '1px dashed #000', paddingBottom: 6 }}>
            <h2 style={{ margin: '0 0 2px 0', fontSize: 18, fontWeight: 'bold', letterSpacing: 1 }}>SABZEEWALA</h2>
            <div style={{ fontSize: 10 }}>10-Minute Farm Fresh Vegetables & Grocery</div>
            <div style={{ fontSize: 9 }}>Official Tax & Delivery Receipt</div>
          </div>

          <div style={{ fontSize: 10, lineHeight: 1.4, borderBottom: '1px dashed #000', paddingBottom: 6, marginBottom: 6 }}>
            <div><strong>Invoice No:</strong> {printOrder.order_number || printOrder.id}</div>
            <div><strong>Date & Time:</strong> {new Date(printOrder.created_at).toLocaleString()}</div>
            <div><strong>Customer:</strong> {printOrder.customer_name}</div>
            <div><strong>Phone:</strong> +{printOrder.customer_phone}</div>
            <div style={{ wordBreak: 'break-word' }}><strong>Address:</strong> {printOrder.delivery_address || 'Customer Address'}</div>
            {printOrder.rider_name && <div><strong>Rider:</strong> {printOrder.rider_name} (+{printOrder.rider_phone})</div>}
          </div>

          <table style={{ width: '100%', fontSize: 10, textAlign: 'left', borderCollapse: 'collapse', marginBottom: 6 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #000' }}>
                <th style={{ padding: '2px 0' }}>Item & Size</th>
                <th style={{ textAlign: 'center' }}>Qty</th>
                <th style={{ textAlign: 'right' }}>Rate</th>
                <th style={{ textAlign: 'right' }}>Amount</th>
              </tr>
            </thead>
            <tbody>
              {(printOrder.order_items || []).map((it, i) => (
                <tr key={i} style={{ borderBottom: '1px dotted #ccc' }}>
                  <td style={{ padding: '3px 0' }}>{it.product_name} ({it.weight || 1}{it.unit || 'x'})</td>
                  <td style={{ textAlign: 'center' }}>×{it.quantity || 1}</td>
                  <td style={{ textAlign: 'right' }}>₹{it.price || 0}</td>
                  <td style={{ textAlign: 'right', fontWeight: 'bold' }}>₹{(it.price || 0) * (it.quantity || 1)}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <div style={{ fontSize: 10, lineHeight: 1.5, borderTop: '1px dashed #000', paddingTop: 6, marginBottom: 8 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span>Items Total:</span>
              <span>₹{(printOrder.order_items || []).reduce((acc, it) => acc + (it.price || 0) * (it.quantity || 1), 0)}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span>Product Handling Charge:</span>
              <span>₹2.00</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span>Delivery Fee:</span>
              <span>{printOrder.delivery_fee ? `₹${printOrder.delivery_fee}` : 'FREE'}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, fontWeight: 'bold', borderTop: '1px solid #000', paddingTop: 4, marginTop: 4 }}>
              <span>NET PAYABLE:</span>
              <span>{money(printOrder.total || orderTotal(printOrder))}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, marginTop: 2 }}>
              <span>Payment Mode:</span>
              <strong>
                {String(printOrder.payment_method || '').toUpperCase() === 'COD'
                  ? 'CASH ON DELIVERY (COLLECT ON DELIVERY)'
                  : `${String(printOrder.payment_method || 'ONLINE').toUpperCase()} (PAID ONLINE)`}
              </strong>
            </div>
          </div>

          <div style={{ textAlign: 'center', fontSize: 9, borderTop: '1px dashed #000', paddingTop: 6 }}>
            <div>🌿 Farm Fresh Guaranteed • Safe & Hygienic</div>
            <div>Thank you for choosing SabzeeWala!</div>
          </div>
        </div>,
        document.body
      )}
    </div>
  );
}

