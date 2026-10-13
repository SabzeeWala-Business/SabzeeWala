import React, { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { PageHead, Modal, Empty, MissingTable } from '../components/ui';

/**
 * Generic CRUD for optional Supabase tables.
 * If table missing → friendly notice (no SQL schema created).
 */
export default function OptionalCrudPage({
  title,
  subtitle,
  table,
  fields,
  columns,
}) {
  const [rows, setRows] = useState([]);
  const [missing, setMissing] = useState(false);
  const [error, setError] = useState('');
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({});

  const blank = () => {
    const o = { id: '' };
    fields.forEach((f) => {
      o[f.key] = f.defaultValue ?? '';
    });
    return o;
  };

  const load = async () => {
    const { data, error: err } = await supabase.from(table).select('*').order('name', { ascending: true });
    if (err) {
      // try without order on name
      const retry = await supabase.from(table).select('*');
      if (retry.error) {
        setMissing(true);
        setRows([]);
        return;
      }
      setMissing(false);
      setRows(retry.data || []);
      return;
    }
    setMissing(false);
    setRows(data || []);
  };

  useEffect(() => {
    load();
  }, [table]);

  const save = async (e) => {
    e.preventDefault();
    const id = form.id || `${table}_${Date.now()}`;
    const payload = { ...form, id };
    const { error: err } = await supabase.from(table).upsert(payload);
    if (err) setError(err.message);
    else {
      setOpen(false);
      load();
    }
  };

  const remove = async (id) => {
    if (!confirm('Delete?')) return;
    await supabase.from(table).delete().eq('id', id);
    load();
  };

  return (
    <div>
      <PageHead
        title={title}
        subtitle={subtitle}
        actions={
          !missing && (
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => {
                setForm(blank());
                setOpen(true);
              }}
            >
              + Add
            </button>
          )
        }
      />
      {missing && <MissingTable name={table} />}
      {error && <div className="sz-alert error">{error}</div>}
      {!missing && (
        <div className="sz-table-wrap">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <table className="sz-table">
              <thead>
                <tr>
                  {columns.map((c) => (
                    <th key={c.key}>{c.label}</th>
                  ))}
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    {columns.map((c) => (
                      <td key={c.key} style={c.key === columns[0].key ? { fontWeight: 700 } : undefined}>
                        {r[c.key] ?? '—'}
                      </td>
                    ))}
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button
                          type="button"
                          className="btn btn-ghost btn-sm"
                          onClick={() => {
                            setForm({ ...blank(), ...r });
                            setOpen(true);
                          }}
                        >
                          Edit
                        </button>
                        <button type="button" className="btn btn-danger btn-sm" onClick={() => remove(r.id)}>
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
      <Modal open={open} title={title} onClose={() => setOpen(false)}>
        <form className="sz-form" onSubmit={save}>
          {fields.map((f) => (
            <div key={f.key}>
              <label>{f.label}</label>
              {f.type === 'textarea' ? (
                <textarea
                  rows={2}
                  required={f.required}
                  value={form[f.key] || ''}
                  onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                />
              ) : f.type === 'select' ? (
                <select
                  required={f.required}
                  value={form[f.key] || ''}
                  onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                >
                  {(f.options || []).map((o) => (
                    <option key={o} value={o}>
                      {o}
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  type={f.type || 'text'}
                  required={f.required}
                  value={form[f.key] || ''}
                  onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                />
              )}
            </div>
          ))}
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
