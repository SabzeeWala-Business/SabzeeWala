import React, { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { money } from '../utils/admin';
import { PageHead, Modal, Empty } from '../components/ui';

export default function DeliveryPage() {
  const [riders, setRiders] = useState([]);
  const [activeOrders, setActiveOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [open, setOpen] = useState(false);

  const [form, setForm] = useState({
    id: '',
    name: '',
    phone: '',
    vehicle_type: 'Motorcycle / Bike',
    vehicle_number: '',
    driving_license: '',
    status: 'available',
    payout_per_order: '35',
  });

  const load = async () => {
    setLoading(true);
    setError('');
    const [dpRes, ordRes] = await Promise.all([
      supabase.from('delivery_partners').select('*').order('name'),
      supabase.from('orders').select('id, rider_id, order_status').in('order_status', ['packing', 'out_for_delivery']),
    ]);

    if (dpRes.error) setError(dpRes.error.message);
    setRiders(dpRes.data || []);
    setActiveOrders(ordRes.data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const save = async (e) => {
    e.preventDefault();
    setError('');
    setOk('');

    const payload = {
      name: form.name.trim(),
      phone: form.phone.trim(),
      vehicle_type: form.vehicle_type,
      vehicle_number: form.vehicle_number?.trim() || null,
      driving_license: form.driving_license?.trim() || null,
      status: form.status,
      payout_per_order: parseFloat(form.payout_per_order) || 35,
    };

    if (form.id) {
      payload.id = form.id;
    }

    const { error: err } = await supabase.from('delivery_partners').upsert(payload);
    if (err) {
      setError(`Failed to save rider: ${err.message}`);
      return;
    }

    setOk('Delivery partner profile saved successfully!');
    setOpen(false);
    load();
  };

  const toggleStatus = async (r) => {
    const next = r.status === 'available' ? 'offline' : 'available';
    await supabase.from('delivery_partners').update({ status: next }).eq('id', r.id);
    load();
  };

  const remove = async (id) => {
    if (!confirm('Remove this delivery rider?')) return;
    const { error: err } = await supabase.from('delivery_partners').delete().eq('id', id);
    if (err) setError(err.message);
    else load();
  };

  return (
    <div>
      <PageHead
        title="Delivery Fleet & Rider Dispatch"
        subtitle="Manage delivery personnel, shift availability, vehicle details, and per-delivery payout rates"
        actions={
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => {
              setForm({
                id: '',
                name: '',
                phone: '',
                vehicle_type: 'Motorcycle / Bike',
                vehicle_number: '',
                driving_license: '',
                status: 'available',
                payout_per_order: '35',
              });
              setOpen(true);
            }}
          >
            + Onboard New Rider
          </button>
        }
      />

      {error && <div className="sz-alert error">{error}</div>}
      {ok && <div className="sz-alert success">{ok}</div>}

      <div className="sz-table-wrap">
        {loading ? (
          <div className="sz-empty">Loading fleet partners…</div>
        ) : riders.length === 0 ? (
          <Empty message="No delivery riders onboarded yet" />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>Rider Name</th>
                <th>Phone Number</th>
                <th>Vehicle & Number</th>
                <th>Shift Status</th>
                <th>Live Active Deliveries</th>
                <th>Payout Rate</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {riders.map((r) => {
                const assignedCount = activeOrders.filter((o) => o.rider_id === r.id).length;
                return (
                  <tr key={r.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <div
                          style={{
                            width: 36,
                            height: 36,
                            borderRadius: '50%',
                            background: '#e0f2fe',
                            color: '#0284c7',
                            display: 'grid',
                            placeItems: 'center',
                            fontWeight: 'bold',
                          }}
                        >
                          🛵
                        </div>
                        <div>
                          <strong style={{ fontSize: 14, color: '#111' }}>{r.name}</strong>
                          <div style={{ fontSize: 11, color: '#888' }}>DL: {r.driving_license || 'Unverified'}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <strong>📞 +{r.phone}</strong>
                    </td>
                    <td>
                      <span className="badge" style={{ background: '#f1f5f9' }}>
                        {r.vehicle_type || 'Bike'}
                      </span>
                      {r.vehicle_number && (
                        <div style={{ fontSize: 11, color: '#475569', marginTop: 2 }}>{r.vehicle_number}</div>
                      )}
                    </td>
                    <td>
                      <button
                        type="button"
                        onClick={() => toggleStatus(r)}
                        style={{ background: 'transparent', cursor: 'pointer' }}
                        title="Click to toggle Shift Available / Offline"
                      >
                        <span
                          className="badge"
                          style={{
                            background:
                              r.status === 'available'
                                ? '#e7f6ea'
                                : r.status === 'on_delivery'
                                ? '#e0f2fe'
                                : '#ffebee',
                            color:
                              r.status === 'available'
                                ? '#0c831f'
                                : r.status === 'on_delivery'
                                ? '#0284c7'
                                : '#e53935',
                            fontWeight: 'bold',
                          }}
                        >
                          {r.status === 'available'
                            ? '🟢 AVAILABLE'
                            : r.status === 'on_delivery'
                            ? '🛵 ON DELIVERY'
                            : '⚪ OFFLINE'}
                        </span>
                      </button>
                    </td>
                    <td>
                      <span
                        className="badge"
                        style={{
                          background: assignedCount > 0 ? '#eff6ff' : '#f8fafc',
                          color: assignedCount > 0 ? '#2563eb' : '#64748b',
                          fontWeight: 'bold',
                        }}
                      >
                        {assignedCount} orders in transit
                      </span>
                    </td>
                    <td>
                      <strong style={{ color: '#0c831f' }}>{money(r.payout_per_order || 35)}</strong> / order
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button
                          type="button"
                          className="btn btn-ghost btn-sm"
                          onClick={() => {
                            setForm(r);
                            setOpen(true);
                          }}
                        >
                          ✏️ Edit
                        </button>
                        <button type="button" className="btn btn-danger btn-sm" onClick={() => remove(r.id)}>
                          🗑️
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Onboard / Edit Rider Modal */}
      {open && (
        <Modal title={form.id ? `Edit Rider: ${form.name}` : 'Onboard Delivery Partner'} onClose={() => setOpen(false)}>
          <form onSubmit={save} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Rider Full Name *</label>
                <input
                  required
                  placeholder="e.g. Sunil Sharma"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Mobile Number *</label>
                <input
                  required
                  placeholder="9876543210"
                  value={form.phone}
                  onChange={(e) => setForm({ ...form, phone: e.target.value })}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Vehicle Type</label>
                <select
                  value={form.vehicle_type}
                  onChange={(e) => setForm({ ...form, vehicle_type: e.target.value })}
                >
                  <option value="Motorcycle / Bike">Motorcycle / Bike</option>
                  <option value="Electric Scooter">Electric Scooter</option>
                  <option value="Bicycle">Bicycle</option>
                </select>
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Vehicle Number Plate</label>
                <input
                  placeholder="BR 07 AB 1234"
                  value={form.vehicle_number}
                  onChange={(e) => setForm({ ...form, vehicle_number: e.target.value })}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Driving License #</label>
                <input
                  placeholder="DL-0420110012345"
                  value={form.driving_license}
                  onChange={(e) => setForm({ ...form, driving_license: e.target.value })}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Payout Rate per Delivery (₹)</label>
                <input
                  type="number"
                  placeholder="35"
                  value={form.payout_per_order}
                  onChange={(e) => setForm({ ...form, payout_per_order: e.target.value })}
                />
              </div>
            </div>

            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Shift Availability</label>
              <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                <option value="available">Available on Shift (Ready for Orders)</option>
                <option value="offline">Offline / Off Shift</option>
                <option value="inactive">Inactive / Suspended</option>
              </select>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 8 }}>
              <button type="button" className="btn btn-ghost" onClick={() => setOpen(false)}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                💾 Save Rider Profile
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
