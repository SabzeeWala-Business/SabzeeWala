import React, { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { money } from '../utils/admin';
import { PageHead, Modal, Empty } from '../components/ui';

export default function CustomerSupportPage() {
  const [tickets, setTickets] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedTicket, setSelectedTicket] = useState(null);
  const [customerOrders, setCustomerOrders] = useState([]);
  const [refundAmount, setRefundAmount] = useState('50');
  const [resolutionNotes, setResolutionNotes] = useState('');
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    const [tRes, uRes] = await Promise.all([
      supabase.from('support_tickets').select('*').order('created_at', { ascending: false }),
      supabase.from('users').select('*'),
    ]);

    if (tRes.error) setError(tRes.error.message);
    setTickets(tRes.data || []);
    setCustomers(uRes.data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const openTicketDrawer = async (t) => {
    setSelectedTicket(t);
    setResolutionNotes(t.resolution_notes || '');
    // Fetch customer previous orders
    const { data: ords } = await supabase
      .from('orders')
      .select('id, total, created_at, order_status')
      .eq('user_id', t.user_id)
      .order('created_at', { ascending: false })
      .limit(5);

    setCustomerOrders(ords || []);
  };

  const updateStatus = async (ticketId, newStatus) => {
    await supabase.from('support_tickets').update({
      status: newStatus,
      resolution_notes: resolutionNotes,
      resolved_at: newStatus === 'resolved' ? new Date().toISOString() : null,
    }).eq('id', ticketId);

    setOk(`Ticket ${ticketId} updated to ${newStatus}`);
    setSelectedTicket(null);
    load();
  };

  const issueWalletCredit = async () => {
    if (!selectedTicket || !refundAmount) return;
    const credit = parseFloat(refundAmount) || 0;
    if (credit <= 0) return;

    const customerId = selectedTicket.user_id;
    if (!confirm(`Credit ₹${credit} to customer (+${selectedTicket.customer_phone || customerId}) wallet?`)) {
      return;
    }

    try {
      // 1. Fetch current wallet balance
      const { data: userData, error: uErr } = await supabase
        .from('users')
        .select('wallet_balance')
        .eq('id', customerId)
        .maybeSingle();
      
      if (uErr) throw uErr;
      
      const currentBalance = parseFloat(userData?.wallet_balance || 0);
      const nextBalance = currentBalance + credit;

      // 2. Update users table wallet_balance
      const { error: wErr } = await supabase
        .from('users')
        .update({ wallet_balance: nextBalance })
        .eq('id', customerId);

      if (wErr) throw wErr;

      // 3. Insert transaction log row
      const { error: tErr } = await supabase
        .from('wallet_transactions')
        .insert({
          user_id: customerId,
          amount: credit,
          type: 'refund',
          description: `Refund for Support Ticket #${selectedTicket.id}`,
          status: 'completed',
        });

      if (tErr) throw tErr;

      // 4. Update support ticket status
      await supabase.from('support_tickets').update({
        status: 'resolved',
        refund_amount: credit,
        resolution_notes: `Credited ₹${credit} to wallet. ${resolutionNotes}`,
        resolved_at: new Date().toISOString(),
      }).eq('id', selectedTicket.id);

      setOk(`₹${credit} compensation credited to customer wallet & ticket resolved!`);
    } catch (err) {
      console.error("Support refund failed:", err);
      setError(`Failed to process support refund: ${err.message}`);
    }

    setSelectedTicket(null);
    load();
  };

  return (
    <div>
      <PageHead
        title="Customer Support & Dispute Resolutions"
        subtitle="Manage customer complaints, missing produce issues, quality checks, and instant wallet refunds"
      />

      {error && <div className="sz-alert error">{error}</div>}
      {ok && <div className="sz-alert success">{ok}</div>}

      <div className="sz-table-wrap">
        {loading ? (
          <div className="sz-empty">Loading support tickets…</div>
        ) : tickets.length === 0 ? (
          <Empty message="No open support tickets. All customer issues resolved!" />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>Ticket ID</th>
                <th>Category</th>
                <th>Subject & Message</th>
                <th>Customer</th>
                <th>Related Order</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {tickets.map((t) => (
                <tr key={t.id}>
                  <td>
                    <strong style={{ color: '#0c831f' }}>{t.id}</strong>
                    <div style={{ fontSize: 11, color: '#888' }}>
                      {new Date(t.created_at).toLocaleDateString()}
                    </div>
                  </td>
                  <td>
                    <span
                      className="badge"
                      style={{
                        background:
                          t.category === 'Missing Item'
                            ? '#fef2f2'
                            : t.category === 'Quality Issue'
                            ? '#fff7ed'
                            : '#eff6ff',
                        color:
                          t.category === 'Missing Item'
                            ? '#ef4444'
                            : t.category === 'Quality Issue'
                            ? '#ea580c'
                            : '#2563eb',
                        fontWeight: 'bold',
                      }}
                    >
                      {t.category || 'General'}
                    </span>
                  </td>
                  <td>
                    <strong style={{ fontSize: 13, display: 'block' }}>{t.subject}</strong>
                    <div style={{ fontSize: 12, color: '#475569', maxWidth: 280, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {t.message}
                    </div>
                  </td>
                  <td>
                    <strong>{t.customer_name || 'Customer'}</strong>
                    <div style={{ fontSize: 11, color: '#64748b' }}>📞 +{t.customer_phone || t.user_id}</div>
                  </td>
                  <td>
                    {t.order_id ? <span className="badge" style={{ background: '#f1f5f9' }}>{t.order_id}</span> : '—'}
                  </td>
                  <td>
                    <span
                      className="badge"
                      style={{
                        background: t.status === 'resolved' ? '#e7f6ea' : t.status === 'in_progress' ? '#fff3e0' : '#ffebee',
                        color: t.status === 'resolved' ? '#0c831f' : t.status === 'in_progress' ? '#ef6c00' : '#e53935',
                        fontWeight: 'bold',
                      }}
                    >
                      {t.status?.toUpperCase() || 'OPEN'}
                    </span>
                  </td>
                  <td>
                    <button type="button" className="btn btn-primary btn-sm" onClick={() => openTicketDrawer(t)}>
                      Resolve Issue
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Ticket Resolution Drawer Modal */}
      {selectedTicket && (
        <Modal title={`Support Ticket: ${selectedTicket.id}`} onClose={() => setSelectedTicket(null)}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {/* Customer Complaint Details */}
            <div style={{ background: '#f8fafc', padding: 14, borderRadius: 10, border: '1px solid #e2e8f0' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                <span className="badge" style={{ background: '#fee2e2', color: '#b91c1c', fontWeight: 'bold' }}>
                  Category: {selectedTicket.category}
                </span>
                <span style={{ fontSize: 11, color: '#64748b' }}>
                  {new Date(selectedTicket.created_at).toLocaleString()}
                </span>
              </div>
              <h3 style={{ fontSize: 15, margin: '0 0 6px 0', color: '#0f172a' }}>{selectedTicket.subject}</h3>
              <p style={{ fontSize: 13, color: '#334155', lineHeight: 1.5, background: '#fff', padding: 10, borderRadius: 8, border: '1px solid #e2e8f0' }}>
                "{selectedTicket.message}"
              </p>
            </div>

            {/* Customer Order History Snapshot */}
            <div>
              <strong style={{ fontSize: 13, display: 'block', marginBottom: 6 }}>
                Customer Recent Orders (+{selectedTicket.customer_phone || selectedTicket.user_id})
              </strong>
              {customerOrders.length === 0 ? (
                <div style={{ fontSize: 12, color: '#888' }}>No previous orders found</div>
              ) : (
                <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 4 }}>
                  {customerOrders.map((o) => (
                    <div
                      key={o.id}
                      style={{
                        background: '#f1f5f9',
                        padding: '8px 12px',
                        borderRadius: 8,
                        fontSize: 11,
                        minWidth: 120,
                      }}
                    >
                      <strong style={{ color: '#0c831f' }}>{o.id}</strong>
                      <div style={{ fontWeight: 'bold' }}>{money(o.total)}</div>
                      <div style={{ color: '#64748b' }}>{o.order_status}</div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Resolution Actions & Instant Wallet Refund */}
            <div style={{ background: '#f0fdf4', padding: 14, borderRadius: 10, border: '1px solid #bbf7d0' }}>
              <strong style={{ color: '#166534', fontSize: 13, display: 'block', marginBottom: 8 }}>
                💳 Instant Wallet Refund & Compensation
              </strong>
              <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                <input
                  type="number"
                  placeholder="Refund ₹"
                  value={refundAmount}
                  onChange={(e) => setRefundAmount(e.target.value)}
                  style={{ maxWidth: 120, borderColor: '#16a34a', fontWeight: 'bold' }}
                />
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={issueWalletCredit}
                  style={{ background: '#16a34a' }}
                >
                  ⚡ Credit to Customer Wallet & Resolve
                </button>
              </div>
            </div>

            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                Resolution Notes / Staff Remarks
              </label>
              <textarea
                rows={2}
                placeholder="Spoke with customer, refund credited for damaged tomatoes..."
                value={resolutionNotes}
                onChange={(e) => setResolutionNotes(e.target.value)}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid #e2e8f0', paddingTop: 12 }}>
              <div style={{ display: 'flex', gap: 6 }}>
                <button type="button" className="btn btn-ghost btn-sm" onClick={() => updateStatus(selectedTicket.id, 'in_progress')}>
                  ⏳ In Progress
                </button>
                <button type="button" className="btn btn-primary btn-sm" onClick={() => updateStatus(selectedTicket.id, 'resolved')}>
                  ✅ Mark Resolved
                </button>
              </div>
              <button type="button" className="btn btn-ghost" onClick={() => setSelectedTicket(null)}>
                Close
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
