import React, { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { PageHead, Empty, Modal } from '../components/ui';

export default function SuppliersPage() {
  const [suppliers, setSuppliers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [open, setOpen] = useState(false);

  const [form, setForm] = useState({
    id: '',
    name: '',
    contact_person: '',
    phone: '',
    email: '',
    gst: '',
    address: '',
    payment_terms: 'Net 15',
    status: 'active',
  });

  const load = async () => {
    setLoading(true);
    setError('');
    const { data, error: err } = await supabase.from('suppliers').select('*').order('name');
    if (err) setError(err.message);
    setSuppliers(data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const filtered = suppliers.filter(
    (s) =>
      s.name?.toLowerCase().includes(search.toLowerCase()) ||
      s.phone?.includes(search) ||
      s.contact_person?.toLowerCase().includes(search.toLowerCase())
  );

  const save = async (e) => {
    e.preventDefault();
    setError('');
    setOk('');

    const payload = {
      name: form.name.trim(),
      contact_person: form.contact_person?.trim() || null,
      phone: form.phone.trim(),
      email: form.email?.trim() || null,
      gst: form.gst?.trim() || null,
      address: form.address?.trim() || null,
      payment_terms: form.payment_terms || 'Net 15',
      status: form.status || 'active',
    };

    if (form.id) {
      payload.id = form.id;
    }

    const { error: err } = await supabase.from('suppliers').upsert(payload);
    if (err) {
      setError(`Failed to save supplier: ${err.message}`);
      return;
    }

    setOk('Supplier profile saved successfully!');
    setOpen(false);
    load();
  };

  const remove = async (id) => {
    if (!confirm('Delete this supplier record?')) return;
    const { error: err } = await supabase.from('suppliers').delete().eq('id', id);
    if (err) setError(err.message);
    else load();
  };

  return (
    <div>
      <PageHead
        title="Supplier & Farm Vendor Directory"
        subtitle="Manage farm vendors, wholesale mandi suppliers, payment terms, and contact profiles"
        actions={
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => {
              setForm({
                id: '',
                name: '',
                contact_person: '',
                phone: '',
                email: '',
                gst: '',
                address: '',
                payment_terms: 'Net 15',
                status: 'active',
              });
              setOpen(true);
            }}
          >
            + Add New Supplier
          </button>
        }
      />

      {error && <div className="sz-alert error">{error}</div>}
      {ok && <div className="sz-alert success">{ok}</div>}

      <div className="sz-toolbar">
        <input
          className="grow"
          placeholder="Search supplier by name, phone, or contact person…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="sz-table-wrap">
        {loading ? (
          <div className="sz-empty">Loading suppliers directory…</div>
        ) : filtered.length === 0 ? (
          <Empty message="No suppliers registered yet" />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>Vendor / Farm Name</th>
                <th>Contact Person</th>
                <th>Phone Number</th>
                <th>Email</th>
                <th>GST / PAN</th>
                <th>Payment Terms</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((s) => (
                <tr key={s.id}>
                  <td>
                    <strong style={{ fontSize: 14, color: '#111' }}>{s.name}</strong>
                    <div style={{ fontSize: 11, color: '#64748b' }}>{s.address || 'No address specified'}</div>
                  </td>
                  <td>{s.contact_person || '—'}</td>
                  <td>
                    <strong>📞 {s.phone}</strong>
                  </td>
                  <td>{s.email || '—'}</td>
                  <td>
                    <span style={{ fontFamily: 'monospace', fontSize: 11 }}>{s.gst || '—'}</span>
                  </td>
                  <td>
                    <span className="badge" style={{ background: '#f8fafc', color: '#334155', border: '1px solid #cbd5e1' }}>
                      {s.payment_terms || 'Cash on Delivery'}
                    </span>
                  </td>
                  <td>
                    <span className="badge" style={{ background: s.status === 'active' ? '#e7f6ea' : '#ffebee', color: s.status === 'active' ? '#0c831f' : '#e53935' }}>
                      {s.status?.toUpperCase() || 'ACTIVE'}
                    </span>
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => {
                          setForm(s);
                          setOpen(true);
                        }}
                      >
                        ✏️ Edit
                      </button>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => remove(s.id)}>
                        🗑️
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Add / Edit Supplier Modal */}
      {open && (
        <Modal
          title={form.id ? `Edit: ${form.name}` : 'Register New Vendor / Farm Supplier'}
          onClose={() => setOpen(false)}
        >
          <form onSubmit={save} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Vendor / Farm Name *</label>
                <input
                  required
                  placeholder="e.g. Kisan Organic Farms, Darbhanga Mandi"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Contact Person</label>
                <input
                  placeholder="e.g. Ramesh Kumar"
                  value={form.contact_person}
                  onChange={(e) => setForm({ ...form, contact_person: e.target.value })}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Phone Number *</label>
                <input
                  required
                  placeholder="+91 98765 43210"
                  value={form.phone}
                  onChange={(e) => setForm({ ...form, phone: e.target.value })}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Email</label>
                <input
                  type="email"
                  placeholder="vendor@farm.com"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>GST / Trade License</label>
                <input
                  placeholder="22AAAAA0000A1Z5"
                  value={form.gst}
                  onChange={(e) => setForm({ ...form, gst: e.target.value })}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Payment Terms</label>
                <select
                  value={form.payment_terms}
                  onChange={(e) => setForm({ ...form, payment_terms: e.target.value })}
                >
                  <option value="Cash on Delivery">Cash on Delivery (COD)</option>
                  <option value="Net 7">Net 7 Days</option>
                  <option value="Net 15">Net 15 Days</option>
                  <option value="Net 30">Net 30 Days</option>
                  <option value="Advance">100% Advance</option>
                </select>
              </div>
            </div>

            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Warehouse / Farm Address</label>
              <textarea
                rows={2}
                placeholder="Village, Mandi Yard, Darbhanga..."
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 8 }}>
              <button type="button" className="btn btn-ghost" onClick={() => setOpen(false)}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                💾 Save Supplier Profile
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
