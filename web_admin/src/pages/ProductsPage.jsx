import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../supabase';
import { statusPill } from '../utils/admin';
import { PageHead, Modal, Empty } from '../components/ui';
import ImageUploader from '../components/ImageUploader';

export default function ProductsPage() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [subs, setSubs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filterCat, setFilterCat] = useState('all');
  const [filterStatus, setFilterStatus] = useState('all');
  const [filterBadge, setFilterBadge] = useState('all');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [open, setOpen] = useState(false);

  // Form State with Multi-Variants
  const [form, setForm] = useState({
    id: '',
    name: '',
    description: '',
    category_id: '',
    sub_category_id: '',
    is_organic: false,
    is_new_launch: false,
    image_url: '',
    status: 'active',
    variants: [
      { id: '', weight: '1', unit: 'kg', mrp: '40', selling_price: '30', purchase_price: '20', stock_total: '50' },
    ],
  });

  const load = async () => {
    setLoading(true);
    const [p, c, s] = await Promise.all([
      supabase.from('products').select('*, categories(name), sub_categories(name), product_variants(*)').order('name'),
      supabase.from('categories').select('id, name').order('name'),
      supabase.from('sub_categories').select('id, name, category_id').order('name'),
    ]);
    if (p.error) setError(p.error.message);
    setProducts(p.data || []);
    setCategories(c.data || []);
    setSubs(s.data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const filtered = useMemo(() => {
    return products.filter((p) => {
      const q = search.toLowerCase();
      const matchQ = !q || p.name?.toLowerCase().includes(q) || p.description?.toLowerCase().includes(q);
      const matchC = filterCat === 'all' || p.category_id === filterCat;
      const matchS = filterStatus === 'all' || p.status === filterStatus;
      const matchB =
        filterBadge === 'all' ||
        (filterBadge === 'organic' && p.is_organic) ||
        (filterBadge === 'new_launch' && p.is_new_launch);
      return matchQ && matchC && matchS && matchB;
    });
  }, [products, search, filterCat, filterStatus, filterBadge]);

  const addVariantRow = () => {
    setForm((prev) => ({
      ...prev,
      variants: [
        ...prev.variants,
        { id: '', weight: '500', unit: 'g', mrp: '30', selling_price: '20', purchase_price: '12', stock_total: '30' },
      ],
    }));
  };

  const removeVariantRow = (index) => {
    if (form.variants.length <= 1) {
      alert('At least one weight variant is required per product.');
      return;
    }
    setForm((prev) => ({
      ...prev,
      variants: prev.variants.filter((_, i) => i !== index),
    }));
  };

  const updateVariantRow = (index, key, val) => {
    setForm((prev) => {
      const updated = [...prev.variants];
      updated[index] = { ...updated[index], [key]: val };
      return { ...prev, variants: updated };
    });
  };

  const openEditModal = (p) => {
    const existingVariants = (p.product_variants || []).map((v) => ({
      id: v.id,
      weight: String(v.weight ?? '1'),
      unit: v.unit || 'kg',
      mrp: String(v.mrp ?? '0'),
      selling_price: String(v.selling_price ?? '0'),
      purchase_price: String(v.purchase_price ?? '0'),
      stock_total: String(v.stock_total ?? '50'),
    }));

    setForm({
      id: p.id,
      name: p.name || '',
      description: p.description || '',
      category_id: p.category_id || (categories[0]?.id || ''),
      sub_category_id: p.sub_category_id || '',
      is_organic: !!p.is_organic,
      is_new_launch: !!p.is_new_launch,
      image_url: p.image_url || '',
      status: p.status || 'active',
      variants: existingVariants.length > 0
        ? existingVariants
        : [{ id: '', weight: '1', unit: 'kg', mrp: '40', selling_price: '30', purchase_price: '20', stock_total: '50' }],
    });
    setOpen(true);
  };

  const save = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    const prodId = form.id || `prod_${Date.now()}`;
    const subCatId = form.sub_category_id && form.sub_category_id.trim() !== '' ? form.sub_category_id.trim() : null;
    
    // 1. Upsert parent Product
    let { error: prodErr } = await supabase.from('products').upsert({
      id: prodId,
      name: form.name.trim(),
      description: form.description?.trim() || '',
      category_id: form.category_id,
      sub_category_id: subCatId,
      is_organic: !!form.is_organic,
      is_new_launch: !!form.is_new_launch,
      image_url: form.image_url || null,
      status: form.status,
    });

    if (prodErr && (prodErr.message?.includes('is_new_launch') || prodErr.code === '42703')) {
      ({ error: prodErr } = await supabase.from('products').upsert({
        id: prodId,
        name: form.name.trim(),
        description: form.description?.trim() || '',
        category_id: form.category_id,
        sub_category_id: subCatId,
        is_organic: !!form.is_organic,
        image_url: form.image_url || null,
        status: form.status,
      }));
    }

    if (prodErr) {
      setError(`Failed to save product: ${prodErr.message}`);
      return;
    }

    // 2. Upsert Variants
    for (const v of form.variants) {
      const variantId = v.id || `var_${prodId}_${v.weight}${v.unit}_${Date.now()}`;
      const { error: vErr } = await supabase.from('product_variants').upsert({
        id: variantId,
        product_id: prodId,
        weight: parseFloat(v.weight) || 1,
        unit: v.unit || 'kg',
        mrp: parseFloat(v.mrp) || 0,
        selling_price: parseFloat(v.selling_price) || 0,
        stock_total: parseInt(v.stock_total, 10) || 0,
        sku: `SKU_${prodId.toUpperCase()}_${v.weight}${v.unit}`,
      });
      if (vErr) {
        console.error('Error saving variant:', vErr);
        setError(`Failed to save variant ${v.weight}${v.unit}: ${vErr.message}`);
        return;
      }
    }

    setSuccess('Product and variants saved successfully!');
    setOpen(false);
    load();
  };

  const toggle = async (p) => {
    const next = p.status === 'active' ? 'inactive' : 'active';
    await supabase.from('products').update({ status: next }).eq('id', p.id);
    load();
  };

  const remove = async (id) => {
    if (!confirm('Are you sure you want to delete this product and all its variants?')) return;
    const { error: err } = await supabase.from('products').delete().eq('id', id);
    if (err) setError(err.message);
    else load();
  };

  return (
    <div>
      <PageHead
        title="Product & Variant Master"
        subtitle="Manage fresh groceries, sizes, organic tags, and live app carousels"
        actions={
          <div style={{ display: 'flex', gap: 10 }}>
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => {
                setForm({
                  id: '',
                  name: '',
                  description: '',
                  category_id: categories[0]?.id || '',
                  sub_category_id: '',
                  is_organic: false,
                  is_new_launch: false,
                  image_url: '',
                  status: 'active',
                  variants: [
                    { id: '', weight: '1', unit: 'kg', mrp: '40', selling_price: '30', purchase_price: '20', stock_total: '50' },
                  ],
                });
                setOpen(true);
              }}
            >
              + Add New Product
            </button>
          </div>
        }
      />

      {error && <div className="sz-alert error">{error}</div>}
      {success && <div className="sz-alert success">{success}</div>}

      <div className="sz-toolbar" style={{ flexWrap: 'wrap', gap: 10 }}>
        <input
          className="grow"
          placeholder="Search by vegetable, fruit or grocery name…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ minWidth: 220 }}
        />
        <select value={filterCat} onChange={(e) => setFilterCat(e.target.value)} style={{ maxWidth: 180 }}>
          <option value="all">All Categories</option>
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
        <select value={filterBadge} onChange={(e) => setFilterBadge(e.target.value)} style={{ maxWidth: 180 }}>
          <option value="all">All Badges</option>
          <option value="organic">🌿 Organic Only</option>
          <option value="new_launch">✨ New Launch Only</option>
        </select>
        <select value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)} style={{ maxWidth: 140 }}>
          <option value="all">All Status</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
      </div>

      <div className="sz-table-wrap">
        {loading ? (
          <div className="sz-empty">Loading fresh catalog…</div>
        ) : filtered.length === 0 ? (
          <Empty message="No products match your criteria" />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>Media</th>
                <th>Product Name</th>
                <th>Category</th>
                <th>App Badges</th>
                <th>Variants & Pricing</th>
                <th>Live Stock</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((p) => {
                const vars = p.product_variants || [];
                const totalStock = vars.reduce((acc, v) => acc + (v.stock_total || 0), 0);
                const minPrice = vars.length > 0 ? Math.min(...vars.map((v) => v.selling_price || 0)) : 0;
                const maxPrice = vars.length > 0 ? Math.max(...vars.map((v) => v.selling_price || 0)) : 0;

                return (
                  <tr key={p.id}>
                    <td>
                      <img
                        src={p.image_url || 'https://via.placeholder.com/60?text=Veg'}
                        alt={p.name}
                        style={{ width: 44, height: 44, objectFit: 'cover', borderRadius: 8, border: '1px solid #eee' }}
                      />
                    </td>
                    <td>
                      <strong style={{ fontSize: 14, color: '#1a1a1a' }}>{p.name}</strong>
                      <div style={{ fontSize: 11, color: '#888', maxWidth: 220, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {p.description || 'No description provided'}
                      </div>
                    </td>
                    <td>
                      <span className="badge" style={{ background: '#f0fdf4', color: '#166534', border: '1px solid #bbf7d0' }}>
                        {p.categories?.name || 'Unassigned'}
                      </span>
                      {p.sub_categories?.name && (
                        <div style={{ fontSize: 11, color: '#666', marginTop: 2 }}>{p.sub_categories.name}</div>
                      )}
                    </td>
                    <td>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                        {p.is_organic && (
                          <span className="badge" style={{ background: '#e8f5e9', color: '#2e7d32', fontWeight: 'bold' }}>
                            🌱 Organic
                          </span>
                        )}
                        {p.is_new_launch && (
                          <span className="badge" style={{ background: '#fff3e0', color: '#e65100', fontWeight: 'bold' }}>
                            🚀 New Launch
                          </span>
                        )}
                        {!p.is_organic && !p.is_new_launch && <span style={{ color: '#aaa', fontSize: 11 }}>Regular</span>}
                      </div>
                    </td>
                    <td>
                      <div style={{ fontWeight: 600, color: '#0c831f' }}>
                        {vars.length === 0
                          ? 'No variants'
                          : minPrice === maxPrice
                          ? `₹${minPrice}`
                          : `₹${minPrice} - ₹${maxPrice}`}
                      </div>
                      <div style={{ fontSize: 11, color: '#666' }}>
                        {vars.map((v) => `${v.weight}${v.unit}`).join(', ')}
                      </div>
                    </td>
                    <td>
                      <span
                        className="badge"
                        style={{
                          background: totalStock > 15 ? '#e7f6ea' : totalStock > 0 ? '#fff3e0' : '#ffebee',
                          color: totalStock > 15 ? '#0c831f' : totalStock > 0 ? '#ef6c00' : '#e53935',
                          fontWeight: 'bold',
                        }}
                      >
                        {totalStock > 0 ? `${totalStock} in stock` : 'Out of Stock'}
                      </span>
                    </td>
                    <td>
                      <button
                        type="button"
                        onClick={() => toggle(p)}
                        style={{ background: 'transparent', cursor: 'pointer' }}
                        title="Click to toggle active/inactive"
                      >
                        {statusPill(p.status)}
                      </button>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => openEditModal(p)}>
                          ✏️ Edit
                        </button>
                        <button type="button" className="btn btn-danger btn-sm" onClick={() => remove(p.id)}>
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

      {/* Unified Add/Edit Modal */}
      {open && (
        <Modal
          title={form.id ? `Edit: ${form.name}` : 'Add New Grocery Product'}
          onClose={() => setOpen(false)}
        >
          <form onSubmit={save} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Product Name *</label>
                <input
                  required
                  placeholder="e.g. Fresh Desi Tomato"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Category *</label>
                <select
                  required
                  value={form.category_id}
                  onChange={(e) => setForm({ ...form, category_id: e.target.value, sub_category_id: '' })}
                >
                  <option value="">Select Category</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Sub Category</label>
                <select
                  value={form.sub_category_id}
                  onChange={(e) => setForm({ ...form, sub_category_id: e.target.value })}
                >
                  <option value="">None (General)</option>
                  {subs
                    .filter((s) => !form.category_id || s.category_id === form.category_id)
                    .map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.name}
                      </option>
                    ))}
                </select>
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Catalog Status</label>
                <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                  <option value="active">Active (Visible in App)</option>
                  <option value="inactive">Inactive (Hidden)</option>
                </select>
              </div>
            </div>

            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Product Image</label>
              <ImageUploader
                value={form.image_url}
                onChange={(url) => setForm({ ...form, image_url: url })}
                bucket="product-images"
              />
            </div>

            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Description & Storage Tips</label>
              <textarea
                rows={2}
                placeholder="Freshly sourced farm tomatoes, ideal for curries and salads..."
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
              />
            </div>

            {/* Mobile App Special Badges */}
            <div style={{ background: '#f9fafb', padding: 12, borderRadius: 10, border: '1px solid #e5e7eb' }}>
              <div style={{ fontSize: 12, fontWeight: 700, marginBottom: 8, color: '#166534' }}>
                ⭐ Home Screen Carousel Settings
              </div>
              <div style={{ display: 'flex', gap: 24 }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>
                  <input
                    type="checkbox"
                    checked={form.is_organic}
                    onChange={(e) => setForm({ ...form, is_organic: e.target.checked })}
                    style={{ width: 'auto' }}
                  />
                  🌱 Mark as Organic (Pushes to Organic Carousel)
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>
                  <input
                    type="checkbox"
                    checked={form.is_new_launch}
                    onChange={(e) => setForm({ ...form, is_new_launch: e.target.checked })}
                    style={{ width: 'auto' }}
                  />
                  🚀 Mark as New Launch (Pushes to New Launch Carousel)
                </label>
              </div>
            </div>

            {/* Multi-Variant Table */}
            <div style={{ border: '1px solid #e2e8f0', borderRadius: 10, padding: 14 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                <div>
                  <strong style={{ fontSize: 13 }}>Product Variants, Sizes & Pricing</strong>
                  <div style={{ fontSize: 11, color: '#666' }}>Add packet sizes with individual selling price and stock</div>
                </div>
                <button type="button" className="btn btn-ghost btn-sm" onClick={addVariantRow} style={{ border: '1px dashed #0c831f' }}>
                  + Add Another Size (e.g. 500g, 1kg)
                </button>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {form.variants.map((v, idx) => {
                  const mrp = parseFloat(v.mrp) || 0;
                  const sell = parseFloat(v.selling_price) || 0;
                  const cost = parseFloat(v.purchase_price) || 0;
                  const margin = sell > 0 ? (((sell - cost) / sell) * 100).toFixed(0) : 0;

                  return (
                    <div
                      key={idx}
                      style={{
                        display: 'grid',
                        gridTemplateColumns: '80px 70px 80px 80px 80px 80px 40px',
                        gap: 8,
                        alignItems: 'center',
                        background: '#fff',
                        padding: '6px 8px',
                        borderRadius: 8,
                        border: '1px solid #f1f5f9',
                      }}
                    >
                      <div>
                        <span style={{ fontSize: 10, color: '#888' }}>Weight</span>
                        <input
                          placeholder="1"
                          value={v.weight}
                          onChange={(e) => updateVariantRow(idx, 'weight', e.target.value)}
                        />
                      </div>
                      <div>
                        <span style={{ fontSize: 10, color: '#888' }}>Unit</span>
                        <select value={v.unit} onChange={(e) => updateVariantRow(idx, 'unit', e.target.value)}>
                          <option value="kg">kg</option>
                          <option value="g">g</option>
                          <option value="pcs">pcs</option>
                          <option value="bunch">bunch</option>
                          <option value="pack">pack</option>
                          <option value="L">L</option>
                        </select>
                      </div>
                      <div>
                        <span style={{ fontSize: 10, color: '#888' }}>Cost (₹)</span>
                        <input
                          type="number"
                          placeholder="20"
                          value={v.purchase_price}
                          onChange={(e) => updateVariantRow(idx, 'purchase_price', e.target.value)}
                        />
                      </div>
                      <div>
                        <span style={{ fontSize: 10, color: '#888' }}>MRP (₹)</span>
                        <input
                          type="number"
                          placeholder="40"
                          value={v.mrp}
                          onChange={(e) => updateVariantRow(idx, 'mrp', e.target.value)}
                        />
                      </div>
                      <div>
                        <span style={{ fontSize: 10, color: '#888' }}>Sell Price</span>
                        <input
                          type="number"
                          placeholder="30"
                          value={v.selling_price}
                          onChange={(e) => updateVariantRow(idx, 'selling_price', e.target.value)}
                          style={{ borderColor: '#0c831f', fontWeight: 'bold' }}
                        />
                      </div>
                      <div>
                        <span style={{ fontSize: 10, color: '#888' }}>Stock</span>
                        <input
                          type="number"
                          placeholder="50"
                          value={v.stock_total}
                          onChange={(e) => updateVariantRow(idx, 'stock_total', e.target.value)}
                        />
                      </div>
                      <button
                        type="button"
                        onClick={() => removeVariantRow(idx)}
                        style={{ color: '#e53935', background: 'transparent', fontSize: 16, marginTop: 12 }}
                        title="Delete this variant size"
                      >
                        ✕
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 8 }}>
              <button type="button" className="btn btn-ghost" onClick={() => setOpen(false)}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                💾 Save Product & Publish to App
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
