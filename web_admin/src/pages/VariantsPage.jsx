import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../supabase';
import { money } from '../utils/admin';
import { getMarketPacks, packKey } from '../utils/marketPacks';
import { PageHead, Modal, Empty } from '../components/ui';

export default function VariantsPage() {
  const [variants, setVariants] = useState([]);
  const [products, setProducts] = useState([]);
  const [filterProduct, setFilterProduct] = useState('all');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    id: '',
    product_id: '',
    weight: '',
    unit: 'g',
    mrp: '',
    selling_price: '',
    sku: '',
    stock_total: '',
  });

  const load = async () => {
    setLoading(true);
    const [v, p] = await Promise.all([
      supabase
        .from('product_variants')
        .select('*, products(name, image_url, category_id, categories(name))')
        .order('weight'),
      supabase.from('products').select('id, name, category_id, categories(name)').order('name'),
    ]);
    if (v.error) setError(v.error.message);
    setVariants(v.data || []);
    setProducts(p.data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const rows =
    filterProduct === 'all' ? variants : variants.filter((v) => v.product_id === filterProduct);

  const suggestedPacks = useMemo(() => {
    if (filterProduct === 'all') return [];
    const p = products.find((x) => x.id === filterProduct);
    if (!p) return [];
    return getMarketPacks(p.name, p.categories?.name || '');
  }, [filterProduct, products]);

  const save = async (e) => {
    e.preventDefault();
    const id = form.id || `var_${Date.now()}`;
    const payload = {
      id,
      product_id: form.product_id,
      weight: form.weight,
      unit: form.unit,
      mrp: parseFloat(form.mrp || 0),
      selling_price: parseFloat(form.selling_price || 0),
      sku: form.sku || `SKU_${id}`.toUpperCase(),
    };
    if (form.stock_total !== '' && form.stock_total != null) {
      payload.stock_total = Math.max(0, Number(form.stock_total) || 0);
    }
    const { error: err } = await supabase.from('product_variants').upsert(payload);
    if (err) {
      if (err.message?.includes('stock_total') || err.code === 'PGRST204') {
        delete payload.stock_total;
        const retry = await supabase.from('product_variants').upsert(payload);
        if (retry.error) setError(retry.error.message);
        else {
          setOpen(false);
          load();
        }
      } else setError(err.message);
    } else {
      setOpen(false);
      load();
    }
  };

  const addSuggestedPacks = async (productId) => {
    const p = products.find((x) => x.id === productId);
    if (!p) return;
    setBusy(true);
    setError('');
    setOk('');
    const packs = getMarketPacks(p.name, p.categories?.name || '');
    const existing = variants.filter((v) => v.product_id === p.id);
    const keys = new Set(existing.map((v) => packKey(v.weight, v.unit)));
    const base = existing.find((v) => Number(v.selling_price) > 0);
    if (!base) {
      setError('Add at least one variant with a selling price before generating suggested pack sizes.');
      setBusy(false);
      return;
    }
    const basePrice = Number(base.selling_price);
    const baseWeight = Number(base.weight) || 1;
    const baseUnit = String(base.unit || 'g').toLowerCase();
    let added = 0;
    for (const pack of packs) {
      const key = packKey(pack.weight, pack.unit);
      if (keys.has(key)) continue;
      const factor = relativeFactor(baseWeight, baseUnit, Number(pack.weight), pack.unit);
      const price = Math.max(1, Math.round(basePrice * factor));
      const id = `var_${p.id}_${pack.weight}${pack.unit}`.replace(/\s/g, '');
      const { error: err } = await supabase.from('product_variants').upsert({
        id,
        product_id: p.id,
        weight: pack.weight,
        unit: pack.unit,
        mrp: Math.round(price * 1.12),
        selling_price: price,
        sku: `SKU_${id}`.toUpperCase().slice(0, 40),
      });
      if (!err) added += 1;
    }
    setOk(
      added
        ? `Added ${added} pack size(s) for ${p.name}. Set stock in Inventory.`
        : `All suggested pack sizes already exist for ${p.name}.`
    );
    setBusy(false);
    load();
  };

  const remove = async (id) => {
    if (!confirm('Delete this variant?')) return;
    const { error: err } = await supabase.from('product_variants').delete().eq('id', id);
    if (err) setError(err.message);
    else load();
  };

  return (
    <div>
      <PageHead
        title="Product Variants"
        subtitle="Weight and pack sizes stored in product_variants — same catalog as the mobile app"
        actions={
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => {
              setForm({
                id: '',
                product_id: filterProduct !== 'all' ? filterProduct : products[0]?.id || '',
                weight: '500',
                unit: 'g',
                mrp: '',
                selling_price: '',
                sku: '',
                stock_total: '',
              });
              setOpen(true);
            }}
          >
            + Add Variant
          </button>
        }
      />
      {error && <div className="sz-alert error">{error}</div>}
      {ok && <div className="sz-alert ok">{ok}</div>}
      <div className="sz-toolbar">
        <select
          value={filterProduct}
          onChange={(e) => setFilterProduct(e.target.value)}
          style={{ maxWidth: 280 }}
        >
          <option value="all">All products</option>
          {products.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
        {filterProduct !== 'all' && (
          <button
            type="button"
            className="btn btn-soft"
            disabled={busy}
            onClick={() => addSuggestedPacks(filterProduct)}
          >
            Add suggested pack sizes
          </button>
        )}
      </div>

      {filterProduct !== 'all' && suggestedPacks.length > 0 && (
        <div className="sz-alert info">
          <strong>Suggested sizes:</strong> {suggestedPacks.map((p) => p.label).join(' · ')}
        </div>
      )}

      <div className="sz-table-wrap">
        {loading ? (
          <div className="sz-empty">Loading…</div>
        ) : rows.length === 0 ? (
          <Empty text="No variants found. Add a variant or select a product to generate suggested sizes." />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>Product</th>
                <th>Weight</th>
                <th>Unit</th>
                <th>MRP</th>
                <th>Selling</th>
                <th>Stock</th>
                <th>SKU</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((v) => (
                <tr key={v.id}>
                  <td style={{ fontWeight: 700 }}>{v.products?.name || v.product_id}</td>
                  <td>{v.weight}</td>
                  <td>{v.unit}</td>
                  <td>{money(v.mrp)}</td>
                  <td style={{ color: 'var(--brand)', fontWeight: 800 }}>{money(v.selling_price)}</td>
                  <td>
                    {v.stock_total != null
                      ? v.stock_total
                      : v.total_stock != null
                        ? v.total_stock
                        : '—'}
                  </td>
                  <td>{v.sku || '—'}</td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => {
                          setForm({
                            id: v.id,
                            product_id: v.product_id,
                            weight: v.weight,
                            unit: v.unit,
                            mrp: v.mrp,
                            selling_price: v.selling_price,
                            sku: v.sku || '',
                            stock_total:
                              v.stock_total != null
                                ? String(v.stock_total)
                                : v.total_stock != null
                                  ? String(v.total_stock)
                                  : '',
                          });
                          setOpen(true);
                        }}
                      >
                        Edit
                      </button>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => remove(v.id)}>
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
      <Modal open={open} title={form.id ? 'Edit Variant' : 'Add Variant'} onClose={() => setOpen(false)}>
        <form className="sz-form" onSubmit={save}>
          <div>
            <label>Product</label>
            <select
              required
              value={form.product_id}
              onChange={(e) => setForm({ ...form, product_id: e.target.value })}
            >
              <option value="">Select</option>
              {products.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </div>
          <div className="sz-form-row">
            <div>
              <label>Weight</label>
              <input
                required
                value={form.weight}
                onChange={(e) => setForm({ ...form, weight: e.target.value })}
              />
            </div>
            <div>
              <label>Unit</label>
              <select value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })}>
                <option value="g">g</option>
                <option value="kg">kg</option>
                <option value="ml">ml</option>
                <option value="liter">liter</option>
                <option value="pcs">pcs</option>
                <option value="dozen">dozen</option>
              </select>
            </div>
          </div>
          <div className="sz-form-row">
            <div>
              <label>MRP</label>
              <input
                type="number"
                required
                value={form.mrp}
                onChange={(e) => setForm({ ...form, mrp: e.target.value })}
              />
            </div>
            <div>
              <label>Selling price</label>
              <input
                type="number"
                required
                value={form.selling_price}
                onChange={(e) => setForm({ ...form, selling_price: e.target.value })}
              />
            </div>
          </div>
          <div className="sz-form-row">
            <div>
              <label>SKU</label>
              <input value={form.sku} onChange={(e) => setForm({ ...form, sku: e.target.value })} />
            </div>
            <div>
              <label>Stock (optional)</label>
              <input
                type="number"
                min="0"
                placeholder="Leave blank if untracked"
                value={form.stock_total}
                onChange={(e) => setForm({ ...form, stock_total: e.target.value })}
              />
            </div>
          </div>
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

/** Scale price from an existing variant weight/unit to a target pack. */
function relativeFactor(baseWeight, baseUnit, targetWeight, targetUnit) {
  const toBase = (w, u) => {
    const n = Number(w) || 0;
    switch (String(u).toLowerCase()) {
      case 'kg':
        return n * 1000;
      case 'liter':
        return n * 1000;
      case 'dozen':
        return n * 12;
      case 'pcs':
        return n;
      case 'ml':
      case 'g':
      default:
        return n;
    }
  };
  const a = toBase(baseWeight, baseUnit);
  const b = toBase(targetWeight, targetUnit);
  if (a <= 0) return 1;
  return b / a;
}
