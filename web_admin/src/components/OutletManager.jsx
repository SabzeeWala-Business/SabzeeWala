import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';

export default function OutletManager() {
  const [outlets, setOutlets] = useState([]);
  const [loading, setLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Form state
  const [form, setForm] = useState({ id: '', name: '', address: '', is_active: true });
  const [editingItem, setEditingItem] = useState(null);

  useEffect(() => {
    fetchOutlets();
  }, []);

  const fetchOutlets = async () => {
    setLoading(true);
    setError('');
    try {
      const { data, error: fetchErr } = await supabase
        .from('outlets')
        .select('*')
        .order('name');

      if (fetchErr) throw fetchErr;
      setOutlets(data || []);
    } catch (err) {
      setError(err.message || 'Failed to load store outlets.');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    setError('');
    setSuccess('');

    try {
      const outletId = form.id || `outlet_${Date.now()}`;
      const { error: upsertErr } = await supabase.from('outlets').upsert({
        id: outletId,
        name: form.name,
        address: form.address,
        is_active: form.is_active,
      });

      if (upsertErr) throw upsertErr;

      setSuccess('Store outlet saved successfully!');
      resetForm();
      fetchOutlets();
    } catch (err) {
      setError(err.message || 'Failed to save store outlet.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleToggleStatus = async (outlet) => {
    setError('');
    setSuccess('');
    const nextStatus = !outlet.is_active;

    try {
      const { error: patchErr } = await supabase
        .from('outlets')
        .update({ is_active: nextStatus })
        .eq('id', outlet.id);

      if (patchErr) throw patchErr;

      setSuccess(`Outlet "${outlet.name}" status updated.`);
      fetchOutlets();
    } catch (err) {
      setError(err.message || 'Failed to update outlet status.');
    }
  };

  const handleDelete = async (outletId) => {
    if (!confirm('Are you sure you want to delete this store outlet?')) return;
    setActionLoading(true);
    setError('');
    setSuccess('');

    try {
      const { error: deleteErr } = await supabase
        .from('outlets')
        .delete()
        .eq('id', outletId);

      if (deleteErr) throw deleteErr;

      setSuccess('Outlet deleted successfully.');
      fetchOutlets();
    } catch (err) {
      setError(err.message || 'Failed to delete outlet.');
    } finally {
      setActionLoading(false);
    }
  };

  const startEdit = (outlet) => {
    setEditingItem(outlet);
    setForm({
      id: outlet.id,
      name: outlet.name,
      address: outlet.address,
      is_active: outlet.is_active,
    });
  };

  const resetForm = () => {
    setEditingItem(null);
    setForm({ id: '', name: '', address: '', is_active: true });
  };

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <div>
          <h1 style={styles.title}>📍 Store Outlets Configuration</h1>
          <p style={styles.subtitle}>Configure physical pick-up locations and toggle storefront operation status</p>
        </div>
      </div>

      {error && <div style={styles.errorAlert}>{error}</div>}
      {success && <div style={styles.successAlert}>{success}</div>}

      <div style={styles.contentGrid}>
        {/* Form Container */}
        <div style={styles.formContainer} className="glass">
          <h3 style={styles.formTitle}>
            {editingItem ? 'Edit Outlet Location' : 'Register New Outlet'}
          </h3>
          <form onSubmit={handleSubmit} style={styles.form}>
            <div style={styles.field}>
              <label style={styles.label}>Outlet Name</label>
              <input
                type="text"
                required
                placeholder="e.g. Sabzee Hub - Kadirabad"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
            </div>
            <div style={styles.field}>
              <label style={styles.label}>Street Address</label>
              <textarea
                required
                rows="3"
                placeholder="e.g. Kadirabad Chowk, near Petrol Pump, Darbhanga"
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
                style={styles.textarea}
              />
            </div>
            <div style={checkboxRowStyle()} className="checkbox-row-container">
              <input
                type="checkbox"
                id="is_active"
                checked={form.is_active}
                onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
                style={{ width: 'auto' }}
              />
              <label htmlFor="is_active" style={{ fontSize: '14px', fontWeight: '600', cursor: 'pointer' }}>
                Open / Operational Status
              </label>
            </div>
            <div style={styles.btnRow}>
              <button type="submit" disabled={actionLoading} style={styles.saveBtn}>
                {actionLoading ? 'Saving...' : 'Save Outlet'}
              </button>
              {editingItem && (
                <button type="button" onClick={resetForm} style={styles.cancelBtn}>
                  Cancel
                </button>
              )}
            </div>
          </form>
        </div>

        {/* Directory List Container */}
        <div style={{ flex: 1 }}>
          <div className="admin-table-container">
            {loading ? (
              <div style={styles.loading}>Retrieving outlet directory...</div>
            ) : outlets.length === 0 ? (
              <div style={styles.loading}>No brick-and-mortar outlets registered. Add one on the left.</div>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Store Outlet</th>
                    <th>Full Address</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {outlets.map((o) => (
                    <tr key={o.id}>
                      <td style={{ fontWeight: '700' }}>{o.name}</td>
                      <td>{o.address}</td>
                      <td>
                        <button
                          onClick={() => handleToggleStatus(o)}
                          style={{
                            ...styles.statusBtn,
                            background: o.is_active ? '#e8f5e9' : '#ffebee',
                            color: o.is_active ? 'var(--accent-color)' : 'var(--danger-color)',
                          }}
                        >
                          {o.is_active ? 'Active / Open' : 'Inactive / Closed'}
                        </button>
                      </td>
                      <td>
                        <div style={styles.actions}>
                          <button onClick={() => startEdit(o)} style={styles.editBtn}>Edit</button>
                          <button onClick={() => handleDelete(o.id)} style={styles.deleteBtn}>Delete</button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

// Helper function for inline layout to satisfy compiler and keep CSS clean
function checkboxRowStyle() {
  return {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    marginTop: '6px',
  };
}

const styles = {
  container: {
    padding: '30px',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '30px',
    flexWrap: 'wrap',
    gap: '20px',
  },
  title: {
    fontSize: '22px',
    fontWeight: '800',
  },
  subtitle: {
    fontSize: '14px',
    color: 'var(--text-muted)',
    marginTop: '4px',
  },
  errorAlert: {
    background: '#ffebee',
    color: 'var(--danger-color)',
    padding: '12px 20px',
    borderRadius: 'var(--radius-md)',
    fontSize: '13px',
    marginBottom: '20px',
    border: '1px solid #ffcdd2',
  },
  successAlert: {
    background: '#e8f5e9',
    color: 'var(--accent-color)',
    padding: '12px 20px',
    borderRadius: 'var(--radius-md)',
    fontSize: '13px',
    marginBottom: '20px',
    border: '1px solid #c8e6c9',
  },
  contentGrid: {
    display: 'flex',
    gap: '30px',
    alignItems: 'flex-start',
    flexWrap: 'wrap',
  },
  formContainer: {
    width: '360px',
    borderRadius: 'var(--radius-md)',
    padding: '24px',
    boxShadow: 'var(--shadow-sm)',
  },
  formTitle: {
    fontSize: '16px',
    fontWeight: '800',
    marginBottom: '20px',
    borderBottom: '1px solid var(--border-color)',
    paddingBottom: '10px',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  },
  field: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  label: {
    fontSize: '12px',
    fontWeight: '700',
    color: 'var(--text-muted)',
    textTransform: 'uppercase',
  },
  textarea: {
    fontFamily: 'inherit',
    resize: 'vertical',
  },
  btnRow: {
    display: 'flex',
    gap: '10px',
    marginTop: '10px',
  },
  saveBtn: {
    flex: 1,
    background: 'var(--primary)',
    color: '#ffffff',
    padding: '12px',
    borderRadius: 'var(--radius-sm)',
    fontSize: '14px',
  },
  cancelBtn: {
    background: 'transparent',
    color: 'var(--text-muted)',
    border: '1px solid var(--border-color)',
    padding: '12px 20px',
    borderRadius: 'var(--radius-sm)',
  },
  statusBtn: {
    padding: '6px 12px',
    borderRadius: '20px',
    fontSize: '12px',
    fontWeight: '600',
  },
  actions: {
    display: 'flex',
    gap: '8px',
  },
  editBtn: {
    background: '#e3f2fd',
    color: 'var(--primary)',
    padding: '6px 12px',
    borderRadius: 'var(--radius-sm)',
    fontSize: '12px',
  },
  deleteBtn: {
    background: '#ffebee',
    color: 'var(--danger-color)',
    padding: '6px 12px',
    borderRadius: 'var(--radius-sm)',
    fontSize: '12px',
  },
  loading: {
    padding: '40px',
    textAlign: 'center',
    color: 'var(--text-muted)',
    fontWeight: '600',
  },
};
