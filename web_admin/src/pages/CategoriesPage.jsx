import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../supabase';
import { statusPill } from '../utils/admin';
import { PageHead, Modal, Empty } from '../components/ui';
import ImageUploader from '../components/ImageUploader';

export default function CategoriesPage() {
  const [categories, setCategories] = useState([]);
  const [subCategories, setSubCategories] = useState([]);
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [open, setOpen] = useState(false);
  const [subModalOpen, setSubModalOpen] = useState(false);
  const [selectedCatForSub, setSelectedCatForSub] = useState(null);
  const [subNameInput, setSubNameInput] = useState('');

  const [form, setForm] = useState({
    id: '',
    name: '',
    icon: '',
    image_url: '',
    display_order: 1,
    status: 'active',
  });

  const load = async () => {
    setLoading(true);
    let c = await supabase.from('categories').select('*').order('name');
    const [s, p] = await Promise.all([
      supabase.from('sub_categories').select('*').order('name'),
      supabase.from('products').select('id, category_id, sub_category_id'),
    ]);
    if (c.error) {
      console.warn('Category query error:', c.error.message);
    }
    const catData = (c.data || []).sort((a, b) => (a.display_order ?? 999) - (b.display_order ?? 999));
    setCategories(catData);
    setSubCategories(s.data || []);
    setProducts(p.data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const counts = useMemo(() => {
    const m = {};
    products.forEach((p) => {
      m[p.category_id] = (m[p.category_id] || 0) + 1;
    });
    return m;
  }, [products]);

  const filtered = useMemo(() => {
    return categories.filter((c) => c.name?.toLowerCase().includes(search.toLowerCase()));
  }, [categories, search]);

  const save = async (e) => {
    e.preventDefault();
    setError('');
    setOk('');
    const id = form.id || form.name.toLowerCase().replace(/[^a-z0-9]/g, '_');
    const payload = {
      id,
      name: form.name.trim(),
      display_order: parseInt(form.display_order, 10) || 1,
      status: form.status || 'active',
      image_url: form.image_url || null,
    };

    const { error: err } = await supabase.from('categories').upsert(payload);
    if (err) {
      setError(`Failed to save category: ${err.message}`);
      return;
    }
    setOk('Category saved and synced with mobile app!');
    setOpen(false);
    load();
  };

  const toggle = async (row) => {
    const next = row.status === 'active' ? 'inactive' : 'active';
    const { error: err } = await supabase.from('categories').update({ status: next }).eq('id', row.id);
    if (err) setError(err.message);
    else load();
  };

  const remove = async (id) => {
    if (!confirm('Are you sure you want to delete this category? Products linked to it may lose categorization.')) return;
    const { error: err } = await supabase.from('categories').delete().eq('id', id);
    if (err) setError(err.message);
    else load();
  };

  // Subcategory management
  const addSubcategory = async (e) => {
    e.preventDefault();
    if (!subNameInput.trim() || !selectedCatForSub) return;
    const subId = `sub_${selectedCatForSub.id}_${Date.now()}`;
    const { error: err } = await supabase.from('sub_categories').upsert({
      id: subId,
      name: subNameInput.trim(),
      category_id: selectedCatForSub.id,
    });
    if (err) setError(err.message);
    else {
      setSubNameInput('');
      setSubModalOpen(false);
      load();
    }
  };

  const removeSubcategory = async (subId) => {
    if (!confirm('Delete this subcategory?')) return;
    const { error: err } = await supabase.from('sub_categories').delete().eq('id', subId);
    if (err) setError(err.message);
    else load();
  };

  return (
    <div>
      <PageHead
        title="Category & Taxonomy Manager"
        subtitle="Manage categories, display ranking for Flutter app top-bar, and subcategory filters"
        actions={
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => {
              setForm({
                id: '',
                name: '',
                icon: '',
                image_url: '',
                display_order: categories.length + 1,
                status: 'active',
              });
              setOpen(true);
            }}
          >
            + Add New Category
          </button>
        }
      />

      {error && <div className="sz-alert error">{error}</div>}
      {ok && <div className="sz-alert success">{ok}</div>}

      <div className="sz-toolbar">
        <input
          className="grow"
          placeholder="Search category name…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="sz-table-wrap">
        {loading ? (
          <div className="sz-empty">Loading categories…</div>
        ) : filtered.length === 0 ? (
          <Empty message="No categories found" />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>App Order</th>
                <th>Icon / Banner</th>
                <th>Category Name</th>
                <th>Sub-Categories</th>
                <th>Active Products</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((r, idx) => {
                const subsForCat = subCategories.filter((s) => s.category_id === r.id);
                return (
                  <tr key={r.id}>
                    <td>
                      <span
                        style={{
                          display: 'inline-block',
                          padding: '4px 10px',
                          background: '#f1f5f9',
                          borderRadius: 6,
                          fontWeight: 800,
                          color: '#0c831f',
                        }}
                      >
                        #{r.display_order ?? idx + 1}
                      </span>
                    </td>
                    <td>
                      {r.image_url || r.icon ? (
                        <img
                          src={r.image_url || r.icon}
                          alt={r.name}
                          style={{ width: 44, height: 44, objectFit: 'cover', borderRadius: 8, border: '1px solid #eee' }}
                        />
                      ) : (
                        <div
                          style={{
                            width: 44,
                            height: 44,
                            borderRadius: 8,
                            background: '#e7f6ea',
                            color: '#0c831f',
                            display: 'grid',
                            placeItems: 'center',
                            fontWeight: 'bold',
                          }}
                        >
                          {(r.name || '?')[0]}
                        </div>
                      )}
                    </td>
                    <td>
                      <strong style={{ fontSize: 14, color: '#111' }}>{r.name}</strong>
                      <div style={{ fontSize: 11, color: '#888' }}>ID: {r.id}</div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
                        {subsForCat.map((s) => (
                          <span
                            key={s.id}
                            style={{
                              background: '#f8fafc',
                              border: '1px solid #cbd5e1',
                              padding: '2px 8px',
                              borderRadius: 12,
                              fontSize: 11,
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 4,
                            }}
                          >
                            {s.name}
                            <button
                              type="button"
                              onClick={() => removeSubcategory(s.id)}
                              style={{ color: '#ef4444', background: 'transparent', cursor: 'pointer', fontSize: 12 }}
                              title="Delete subcategory"
                            >
                              ×
                            </button>
                          </span>
                        ))}
                        <button
                          type="button"
                          className="btn btn-ghost btn-sm"
                          style={{ fontSize: 11, padding: '2px 6px', border: '1px dashed #94a3b8' }}
                          onClick={() => {
                            setSelectedCatForSub(r);
                            setSubNameInput('');
                            setSubModalOpen(true);
                          }}
                        >
                          + Add Sub
                        </button>
                      </div>
                    </td>
                    <td>
                      <span className="badge" style={{ background: '#f0fdf4', color: '#166534', fontWeight: 600 }}>
                        {counts[r.id] || 0} products
                      </span>
                    </td>
                    <td>
                      <button
                        type="button"
                        onClick={() => toggle(r)}
                        style={{ background: 'transparent', cursor: 'pointer' }}
                        title="Click to toggle active/inactive"
                      >
                        {statusPill(r.status || 'active')}
                      </button>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button
                          type="button"
                          className="btn btn-ghost btn-sm"
                          onClick={() => {
                            setForm({
                              id: r.id,
                              name: r.name,
                              icon: r.icon || '',
                              image_url: r.image_url || '',
                              display_order: r.display_order ?? idx + 1,
                              status: r.status || 'active',
                            });
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

      {/* Add / Edit Category Modal */}
      {open && (
        <Modal
          title={form.id ? `Edit Category: ${form.name}` : 'Add New Category'}
          onClose={() => setOpen(false)}
        >
          <form onSubmit={save} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Category Name *</label>
              <input
                required
                placeholder="e.g. Fresh Vegetables, Exotic Fruits"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                  Display Priority Rank *
                </label>
                <input
                  type="number"
                  required
                  min={1}
                  value={form.display_order}
                  onChange={(e) => setForm({ ...form, display_order: e.target.value })}
                  title="Lower numbers appear first on the mobile app bar"
                />
                <span style={{ fontSize: 11, color: '#888' }}>Rank 1 = Top of mobile app list</span>
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Category Status</label>
                <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                  <option value="active">Active (Visible in App)</option>
                  <option value="inactive">Inactive (Hidden)</option>
                </select>
              </div>
            </div>

            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Category Icon / Banner</label>
              <ImageUploader
                value={form.image_url}
                onChange={(url) => setForm({ ...form, image_url: url })}
                bucket="category-icons"
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 8 }}>
              <button type="button" className="btn btn-ghost" onClick={() => setOpen(false)}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                💾 Save Category
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* Add Subcategory Modal */}
      {subModalOpen && selectedCatForSub && (
        <Modal
          title={`Add Sub-category under "${selectedCatForSub.name}"`}
          onClose={() => setSubModalOpen(false)}
        >
          <form onSubmit={addSubcategory} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Sub-category Name *</label>
              <input
                required
                placeholder="e.g. Leafy Greens, Root Veggies, Organic"
                value={subNameInput}
                onChange={(e) => setSubNameInput(e.target.value)}
                autoFocus
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              <button type="button" className="btn btn-ghost" onClick={() => setSubModalOpen(false)}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                + Add Sub-category
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
