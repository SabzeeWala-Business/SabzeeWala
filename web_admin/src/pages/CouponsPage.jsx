import React, { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { money } from '../utils/admin';
import { PageHead, Modal, Empty } from '../components/ui';

export default function CouponsPage() {
  const [coupons, setCoupons] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [open, setOpen] = useState(false);

  const [form, setForm] = useState({
    code: '',
    type: 'flat',
    value: '50',
    min_order: '199',
    max_discount: '100',
    usage_limit: '500',
    category_id: '',
    expiry_date: '',
  });

  const load = async () => {
    setLoading(true);
    setError('');
    const [coupRes, catRes] = await Promise.all([
      supabase.from('coupons').select('*').order('code'),
      supabase.from('categories').select('id, name').order('name'),
    ]);

    if (coupRes.error) setError(coupRes.error.message);
    setCoupons(coupRes.data || []);
    setCategories(catRes.data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
    const ch = supabase
      .channel('live-coupons-admin')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'coupons' }, () => {
        load();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(ch);
    };
  }, []);

  const save = async (e) => {
    e.preventDefault();
    setError('');
    setOk('');

    const payload = {
      code: form.code.trim().toUpperCase(),
      type: form.type,
      value: parseFloat(form.value) || 0,
      min_order: parseFloat(form.min_order) || 0,
      max_discount: form.max_discount ? parseFloat(form.max_discount) : null,
      usage_limit: form.usage_limit ? parseInt(form.usage_limit, 10) : null,
      expiry_date: form.expiry_date || null,
    };

    const { error: err } = await supabase.from('coupons').upsert(payload, { onConflict: 'code' });
    if (err) {
      setError(`Failed to save coupon: ${err.message}`);
      return;
    }

    setOk(`Coupon ${payload.code} saved and active for mobile app users!`);
    setOpen(false);
    load();
  };

  const remove = async (code) => {
    if (!confirm(`Delete coupon ${code}?`)) return;
    const { error: err } = await supabase.from('coupons').delete().eq('code', code);
    if (err) setError(err.message);
    else load();
  };

  return (
    <div>
      <PageHead
        title="Coupons & Promotional Discounts"
        subtitle="Create discount voucher codes, set minimum cart conditions, and configure promotional campaigns"
        actions={
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => {
              setForm({
                code: '',
                type: 'flat',
                value: '50',
                min_order: '199',
                max_discount: '100',
                usage_limit: '500',
                category_id: '',
                expiry_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
              });
              setOpen(true);
            }}
          >
            + Create New Coupon
          </button>
        }
      />

      {error && <div className="sz-alert error">{error}</div>}
      {ok && <div className="sz-alert success">{ok}</div>}

      <div className="sz-table-wrap">
        {loading ? (
          <div className="sz-empty">Loading coupons…</div>
        ) : coupons.length === 0 ? (
          <Empty message="No active coupons created yet" />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>Coupon Code</th>
                <th>Discount Value</th>
                <th>Min Cart Value</th>
                <th>Max Cap</th>
                <th>Eligible Category</th>
                <th>Usage Limit</th>
                <th>Expiry Date</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {coupons.map((c) => {
                const cat = categories.find((cat) => cat.id === c.category_id);
                return (
                  <tr key={c.code}>
                    <td>
                      <span
                        style={{
                          background: '#f0fdf4',
                          border: '1px dashed #16a34a',
                          color: '#15803d',
                          fontWeight: 800,
                          padding: '4px 10px',
                          borderRadius: 6,
                          fontSize: 13,
                          letterSpacing: 1,
                        }}
                      >
                        {c.code}
                      </span>
                    </td>
                    <td>
                      <strong style={{ color: '#0c831f', fontSize: 14 }}>
                        {c.type === 'flat' ? money(c.value) : `${c.value}% OFF`}
                      </strong>
                    </td>
                    <td>{money(c.min_order || 0)}</td>
                    <td>{c.max_discount ? money(c.max_discount) : 'No Cap'}</td>
                    <td>
                      <span className="badge" style={{ background: '#f1f5f9' }}>
                        {cat?.name || 'All Categories'}
                      </span>
                    </td>
                    <td>{c.usage_limit ? `${c.usage_limit} uses` : 'Unlimited'}</td>
                    <td>
                      <span style={{ fontSize: 12, color: '#64748b' }}>
                        {c.expiry_date ? new Date(c.expiry_date).toLocaleDateString() : 'Never'}
                      </span>
                    </td>
                    <td>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => remove(c.code)}>
                        🗑️ Delete
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Create Coupon Modal */}
      {open && (
        <Modal title="Create Promotional Coupon" onClose={() => setOpen(false)}>
          <form onSubmit={save} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Coupon Code *</label>
                <input
                  required
                  placeholder="e.g. WELCOME50, SABZEE100"
                  value={form.code}
                  onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })}
                  style={{ textTransform: 'uppercase', fontWeight: 'bold' }}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Discount Type *</label>
                <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
                  <option value="flat">Flat Amount (₹)</option>
                  <option value="percentage">Percentage Discount (%)</option>
                </select>
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Discount Value *</label>
                <input
                  type="number"
                  required
                  placeholder={form.type === 'flat' ? '50' : '20'}
                  value={form.value}
                  onChange={(e) => setForm({ ...form, value: e.target.value })}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Minimum Order (₹)</label>
                <input
                  type="number"
                  placeholder="199"
                  value={form.min_order}
                  onChange={(e) => setForm({ ...form, min_order: e.target.value })}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Maximum Discount Cap (₹)</label>
                <input
                  type="number"
                  placeholder="100"
                  value={form.max_discount}
                  onChange={(e) => setForm({ ...form, max_discount: e.target.value })}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Applicable Scope</label>
                <input
                  type="text"
                  disabled
                  value="All Catalog Products"
                  style={{ background: '#f8fafc', color: '#64748b' }}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Usage Limit</label>
                <input
                  type="number"
                  placeholder="500"
                  value={form.usage_limit}
                  onChange={(e) => setForm({ ...form, usage_limit: e.target.value })}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Expiry Date</label>
                <input
                  type="date"
                  value={form.expiry_date}
                  onChange={(e) => setForm({ ...form, expiry_date: e.target.value })}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 8 }}>
              <button type="button" className="btn btn-ghost" onClick={() => setOpen(false)}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                🏷️ Publish Coupon to App
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
