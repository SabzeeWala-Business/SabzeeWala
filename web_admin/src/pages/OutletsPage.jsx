import React, { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { PageHead, Modal, Empty } from '../components/ui';

export default function OutletsPage() {
  const [rows, setRows] = useState([]);
  const [error, setError] = useState('');
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ id: '', name: '', address: '', is_active: true });

  const load = async () => {
    const { data, error: err } = await supabase.from('outlets').select('*').order('name');
    if (err) setError(err.message);
    setRows(data || []);
  };

  useEffect(() => {
    load();
  }, []);

  const save = async (e) => {
    e.preventDefault();
    const { error: err } = await supabase.from('outlets').upsert({
      id: form.id || `outlet_${Date.now()}`,
      name: form.name,
      address: form.address,
      is_active: !!form.is_active,
    });
    if (err) setError(err.message);
    else {
      setOpen(false);
      load();
    }
  };

  return (
    <div>
      <PageHead
        title="Store Outlets / Warehouses"
        subtitle="Pickup points & warehouses"
        actions={
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => {
              setForm({ id: '', name: '', address: '', is_active: true });
              setOpen(true);
            }}
          >
            + Add Outlet
          </button>
        }
      />
      {error && <div className="sz-alert error">{error}</div>}
      <div className="sz-table-wrap">
        {rows.length === 0 ? (
          <Empty />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Address</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td style={{ fontWeight: 700 }}>{r.name}</td>
                  <td>{r.address}</td>
                  <td>
                    <span className={`sz-pill ${r.is_active ? 'ok' : 'danger'}`}>
                      {r.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td>
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm"
                      onClick={() => {
                        setForm(r);
                        setOpen(true);
                      }}
                    >
                      Edit
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      <Modal open={open} title="Outlet" onClose={() => setOpen(false)}>
        <form className="sz-form" onSubmit={save}>
          <div>
            <label>Name</label>
            <input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </div>
          <div>
            <label>Address</label>
            <textarea required rows={2} value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
          </div>
          <label style={{ display: 'flex', gap: 8, alignItems: 'center', textTransform: 'none' }}>
            <input
              type="checkbox"
              checked={!!form.is_active}
              onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
              style={{ width: 'auto' }}
            />
            Active
          </label>
          <div className="sz-form-actions">
            <button type="button" className="btn btn-ghost" onClick={() => setOpen(false)}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary">
              Save
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
