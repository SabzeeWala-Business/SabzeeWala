import React, { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { PageHead, Modal, Empty } from '../components/ui';
import ImageUploader from '../components/ImageUploader';

export default function SubCategoriesPage() {
  const [rows, setRows] = useState([]);
  const [categories, setCategories] = useState([]);
  const [filterCat, setFilterCat] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ id: '', name: '', category_id: '', image_url: '' });

  const load = async () => {
    setLoading(true);
    const [s, c] = await Promise.all([
      supabase.from('sub_categories').select('*').order('name'),
      supabase.from('categories').select('id, name').order('name'),
    ]);
    if (s.error) setError(s.error.message);
    setRows(s.data || []);
    setCategories(c.data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const filtered = filterCat === 'all' ? rows : rows.filter((r) => r.category_id === filterCat);

  const save = async (e) => {
    e.preventDefault();
    const id = form.id || form.name.toLowerCase().replace(/\s+/g, '_');
    const { error: err } = await supabase.from('sub_categories').upsert({
      id,
      name: form.name,
      category_id: form.category_id,
      image_url: form.image_url || null,
    });
    if (err) setError(err.message);
    else {
      setOpen(false);
      load();
    }
  };

  const remove = async (id) => {
    if (!confirm('Delete subcategory?')) return;
    const { error: err } = await supabase.from('sub_categories').delete().eq('id', id);
    if (err) setError(err.message);
    else load();
  };

  const catName = (id) => categories.find((c) => c.id === id)?.name || id;

  return (
    <div>
      <PageHead
        title="Sub Categories"
        subtitle="Filter by parent category"
        actions={
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => {
              setForm({ id: '', name: '', category_id: categories[0]?.id || '', image_url: '' });
              setOpen(true);
            }}
          >
            + Add Sub Category
          </button>
        }
      />
      {error && <div className="sz-alert error">{error}</div>}
      <div className="sz-toolbar">
        <select style={{ maxWidth: 240 }} value={filterCat} onChange={(e) => setFilterCat(e.target.value)}>
          <option value="all">All categories</option>
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </div>
      <div className="sz-table-wrap">
        {loading ? (
          <div className="sz-empty">Loading…</div>
        ) : filtered.length === 0 ? (
          <Empty />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>Image</th>
                <th>Name</th>
                <th>Category</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((r) => (
                <tr key={r.id}>
                  <td>
                    {r.image_url ? <img className="sz-thumb" src={r.image_url} alt="" /> : <div className="sz-thumb-ph">SC</div>}
                  </td>
                  <td style={{ fontWeight: 700 }}>{r.name}</td>
                  <td>{catName(r.category_id)}</td>
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
      <Modal open={open} title="Sub Category" onClose={() => setOpen(false)}>
        <form className="sz-form" onSubmit={save}>
          <div>
            <label>Name</label>
            <input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </div>
          <div>
            <label>Category</label>
            <select required value={form.category_id} onChange={(e) => setForm({ ...form, category_id: e.target.value })}>
              <option value="">Select</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>
          <ImageUploader
            folder="Sub Categories"
            value={form.image_url}
            onChange={(url) => setForm({ ...form, image_url: url })}
          />
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
