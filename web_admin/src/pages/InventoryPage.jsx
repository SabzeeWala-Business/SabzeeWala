import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../supabase';
import { money } from '../utils/admin';
import { getVariantStock, setVariantStock } from '../utils/stock';
import { PageHead, Empty, Modal } from '../components/ui';

export default function InventoryPage() {
  const [activeTab, setActiveTab] = useState('stock'); // 'stock' | 'wastage'
  const [rows, setRows] = useState([]);
  const [wastageLogs, setWastageLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [wastageModalOpen, setWastageModalOpen] = useState(false);
  const [selectedVariantForWastage, setSelectedVariantForWastage] = useState(null);

  const [wastageForm, setWastageForm] = useState({
    quantity: '1',
    reason: 'damaged',
    notes: '',
  });

  const load = async () => {
    setLoading(true);
    setError('');
    const [varRes, wasteRes] = await Promise.all([
      supabase.from('product_variants').select('*, products(id, name, status, image_url, category_id)'),
      supabase.from('inventory_wastage').select('*').order('created_at', { ascending: false }).limit(50),
    ]);

    if (varRes.error) setError(varRes.error.message);
    setRows(varRes.data || []);
    setWastageLogs(wasteRes.data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const enriched = useMemo(() => {
    return rows.map((v) => {
      const total = getVariantStock(v);
      const reserved = Number(v.stock_reserved ?? 0);
      const available = total == null ? 0 : Math.max(total - reserved, 0);
      const inactive = String(v.products?.status).toLowerCase() === 'inactive';
      let invStatus = 'In stock';
      if (available <= 0 || inactive) invStatus = 'Out of stock';
      else if (available < 10) invStatus = 'Low stock';

      return {
        ...v,
        total: total ?? 0,
        reserved,
        available,
        invStatus,
      };
    });
  }, [rows]);

  const filtered = useMemo(() => {
    return enriched.filter((r) => {
      const q = search.toLowerCase();
      const matchQ =
        !q ||
        r.products?.name?.toLowerCase().includes(q) ||
        String(r.sku || '').toLowerCase().includes(q);
      const matchF =
        filter === 'all' ||
        (filter === 'out' && r.invStatus === 'Out of stock') ||
        (filter === 'low' && r.invStatus === 'Low stock') ||
        (filter === 'in' && r.invStatus === 'In stock');
      return matchQ && matchF;
    });
  }, [enriched, search, filter]);

  const adjustStock = async (row, delta) => {
    setError('');
    setOk('');
    try {
      const next = Math.max(0, (row.total || 0) + delta);
      await setVariantStock(row.id, row.product_id, next);
      setOk(`Updated ${row.products?.name || 'item'} stock → ${next}`);
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const setExact = async (row) => {
    const raw = window.prompt(
      `Set direct stock quantity for ${row.products?.name} (${row.weight} ${row.unit})`,
      String(row.total ?? 0)
    );
    if (raw == null) return;
    const qty = parseInt(raw, 10);
    if (Number.isNaN(qty) || qty < 0) {
      setError('Please enter a valid non-negative number');
      return;
    }
    try {
      await setVariantStock(row.id, row.product_id, qty);
      setOk(`Stock set to ${qty} for ${row.products?.name}`);
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const submitWastage = async (e) => {
    e.preventDefault();
    if (!selectedVariantForWastage) return;
    const qtyToDeduct = parseFloat(wastageForm.quantity) || 1;
    const prodName = selectedVariantForWastage.products?.name || 'Produce';
    const costPrice = parseFloat(selectedVariantForWastage.purchase_price || selectedVariantForWastage.selling_price || 0);
    const lossAmount = costPrice * qtyToDeduct;

    // 1. Insert into inventory_wastage log
    const { error: wErr } = await supabase.from('inventory_wastage').insert({
      variant_id: selectedVariantForWastage.id,
      product_name: `${prodName} (${selectedVariantForWastage.weight}${selectedVariantForWastage.unit})`,
      quantity: qtyToDeduct,
      reason: wastageForm.reason,
      cost_loss: lossAmount,
      logged_by: 'Admin',
    });

    if (wErr) {
      console.warn('Wastage logging error:', wErr.message);
    }

    // 2. Deduct from live stock
    const currentStock = selectedVariantForWastage.total || 0;
    const nextStock = Math.max(0, currentStock - qtyToDeduct);
    await setVariantStock(selectedVariantForWastage.id, selectedVariantForWastage.product_id, nextStock);

    setOk(`Logged ${qtyToDeduct} units wastage for ${prodName}. Stock updated to ${nextStock}.`);
    setWastageModalOpen(false);
    load();
  };

  return (
    <div>
      <PageHead
        title="Live Inventory & Wastage Tracker"
        subtitle="Manage live warehouse stock, monitor low-stock thresholds, and log perishable spoilage"
        actions={
          <div style={{ display: 'flex', gap: 10 }}>
            <div style={{ background: '#e2e8f0', borderRadius: 8, padding: 2, display: 'flex' }}>
              <button
                type="button"
                className={`btn btn-sm ${activeTab === 'stock' ? 'btn-primary' : 'btn-ghost'}`}
                onClick={() => setActiveTab('stock')}
                style={{ padding: '6px 14px' }}
              >
                📦 Live Stock Levels
              </button>
              <button
                type="button"
                className={`btn btn-sm ${activeTab === 'wastage' ? 'btn-primary' : 'btn-ghost'}`}
                onClick={() => setActiveTab('wastage')}
                style={{ padding: '6px 14px' }}
              >
                🍂 Spoilage & Wastage Log ({wastageLogs.length})
              </button>
            </div>
          </div>
        }
      />

      {error && <div className="sz-alert error">{error}</div>}
      {ok && <div className="sz-alert success">{ok}</div>}

      {activeTab === 'stock' ? (
        <>
          <div className="sz-toolbar">
            <input
              className="grow"
              placeholder="Search by vegetable/fruit name or SKU…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <select value={filter} onChange={(e) => setFilter(e.target.value)} style={{ maxWidth: 180 }}>
              <option value="all">All Inventory ({enriched.length})</option>
              <option value="in">🟢 In Stock</option>
              <option value="low">🟡 Low Stock (&lt; 10)</option>
              <option value="out">🔴 Out of Stock (0)</option>
            </select>
          </div>

          <div className="sz-table-wrap">
            {loading ? (
              <div className="sz-empty">Loading inventory counts…</div>
            ) : filtered.length === 0 ? (
              <Empty message="No inventory items found" />
            ) : (
              <table className="sz-table">
                <thead>
                  <tr>
                    <th>Item</th>
                    <th>Size</th>
                    <th>Selling Price</th>
                    <th>Cost Price</th>
                    <th>Current Stock</th>
                    <th>Stock Status</th>
                    <th>Quick Adjust (+ / -)</th>
                    <th>Log Wastage</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((r) => {
                    return (
                      <tr key={r.id}>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                            <img
                              src={r.products?.image_url || 'https://via.placeholder.com/40'}
                              alt=""
                              style={{ width: 34, height: 34, objectFit: 'cover', borderRadius: 6 }}
                            />
                            <div>
                              <strong style={{ color: '#111' }}>{r.products?.name || 'Item'}</strong>
                              <div style={{ fontSize: 11, color: '#888' }}>ID: {r.id}</div>
                            </div>
                          </div>
                        </td>
                        <td>
                          <span style={{ fontWeight: 600 }}>{r.weight} {r.unit}</span>
                        </td>
                        <td>{money(r.selling_price || 0)}</td>
                        <td style={{ color: '#64748b' }}>{money(r.purchase_price || 0)}</td>
                        <td>
                          <button
                            type="button"
                            onClick={() => setExact(r)}
                            style={{
                              background: '#f1f5f9',
                              padding: '4px 10px',
                              borderRadius: 6,
                              fontWeight: 800,
                              fontSize: 14,
                              color: '#0f172a',
                              cursor: 'pointer',
                              border: '1px solid #cbd5e1',
                            }}
                            title="Click to set exact number"
                          >
                            {r.total} units
                          </button>
                        </td>
                        <td>
                          <span
                            className="badge"
                            style={{
                              background:
                                r.invStatus === 'In stock'
                                  ? '#e7f6ea'
                                  : r.invStatus === 'Low stock'
                                  ? '#fff3e0'
                                  : '#ffebee',
                              color:
                                r.invStatus === 'In stock'
                                  ? '#0c831f'
                                  : r.invStatus === 'Low stock'
                                  ? '#ef6c00'
                                  : '#e53935',
                              fontWeight: 'bold',
                            }}
                          >
                            {r.invStatus}
                          </span>
                        </td>
                        <td>
                          <div style={{ display: 'flex', gap: 4 }}>
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm"
                              style={{ padding: '2px 8px', fontWeight: 'bold' }}
                              onClick={() => adjustStock(r, -1)}
                            >
                              -1
                            </button>
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm"
                              style={{ padding: '2px 8px', fontWeight: 'bold' }}
                              onClick={() => adjustStock(r, 5)}
                            >
                              +5
                            </button>
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm"
                              style={{ padding: '2px 8px', fontWeight: 'bold' }}
                              onClick={() => adjustStock(r, 20)}
                            >
                              +20
                            </button>
                          </div>
                        </td>
                        <td>
                          <button
                            type="button"
                            className="btn btn-danger btn-sm"
                            style={{ fontSize: 11, padding: '4px 8px' }}
                            onClick={() => {
                              setSelectedVariantForWastage(r);
                              setWastageForm({ quantity: '1', reason: 'damaged', notes: '' });
                              setWastageModalOpen(true);
                            }}
                          >
                            🍂 Log Spoilage
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>
        </>
      ) : (
        /* Spoilage / Wastage Log Table */
        <div className="sz-table-wrap">
          {wastageLogs.length === 0 ? (
            <Empty message="No spoilage or wastage logged yet" />
          ) : (
            <table className="sz-table">
              <thead>
                <tr>
                  <th>Date & Time</th>
                  <th>Product Item</th>
                  <th>Quantity Lost</th>
                  <th>Reason</th>
                  <th>Estimated Loss (₹)</th>
                  <th>Logged By</th>
                </tr>
              </thead>
              <tbody>
                {wastageLogs.map((w) => (
                  <tr key={w.id}>
                    <td style={{ fontSize: 12, color: '#64748b' }}>
                      {new Date(w.created_at).toLocaleString()}
                    </td>
                    <td>
                      <strong>{w.product_name}</strong>
                    </td>
                    <td style={{ fontWeight: 'bold', color: '#e53935' }}>
                      -{w.quantity} units
                    </td>
                    <td>
                      <span className="badge" style={{ background: '#fef2f2', color: '#ef4444' }}>
                        {w.reason?.replace('_', ' ').toUpperCase()}
                      </span>
                    </td>
                    <td style={{ fontWeight: 700 }}>{money(w.cost_loss || 0)}</td>
                    <td>{w.logged_by || 'Admin'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* Log Wastage Modal */}
      {wastageModalOpen && selectedVariantForWastage && (
        <Modal
          title={`Log Wastage / Spoilage for ${selectedVariantForWastage.products?.name} (${selectedVariantForWastage.weight}${selectedVariantForWastage.unit})`}
          onClose={() => setWastageModalOpen(false)}
        >
          <form onSubmit={submitWastage} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                Quantity Spoiled / Discarded (Units) *
              </label>
              <input
                type="number"
                step="0.5"
                min="0.5"
                required
                value={wastageForm.quantity}
                onChange={(e) => setWastageForm({ ...wastageForm, quantity: e.target.value })}
              />
              <span style={{ fontSize: 11, color: '#888' }}>
                Current live stock: {selectedVariantForWastage.total} units
              </span>
            </div>

            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                Primary Reason for Wastage *
              </label>
              <select
                value={wastageForm.reason}
                onChange={(e) => setWastageForm({ ...wastageForm, reason: e.target.value })}
              >
                <option value="damaged">💥 Physical Damage in Transit</option>
                <option value="expired">⏳ Expired / Past Shelf Life</option>
                <option value="shrinkage">🥀 Perished / Weight Shrinkage</option>
                <option value="quality_rejection">🚫 Quality Rejection at Sorting</option>
              </select>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              <button type="button" className="btn btn-ghost" onClick={() => setWastageModalOpen(false)}>
                Cancel
              </button>
              <button type="submit" className="btn btn-danger">
                🍂 Confirm & Deduct from Stock
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
