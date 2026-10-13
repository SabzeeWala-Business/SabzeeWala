import React, { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { money } from '../utils/admin';
import { setVariantStock, getVariantStock } from '../utils/stock';
import { PageHead, Empty, Modal } from '../components/ui';

export default function PurchaseOrdersPage() {
  const [pos, setPos] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [variants, setVariants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [open, setOpen] = useState(false);
  const [viewPo, setViewPo] = useState(null);

  const [form, setForm] = useState({
    supplier_id: '',
    expected_delivery_date: '',
    notes: '',
    items: [
      { variant_id: '', product_name: '', quantity: '50', unit_price: '20', total: 1000 },
    ],
  });

  const load = async () => {
    setLoading(true);
    setError('');
    const [poRes, supRes, varRes] = await Promise.all([
      supabase.from('purchase_orders').select('*').order('created_at', { ascending: false }),
      supabase.from('suppliers').select('id, name').order('name'),
      supabase.from('product_variants').select('id, weight, unit, purchase_price, products(id, name)'),
    ]);

    if (poRes.error) setError(poRes.error.message);
    setPos(poRes.data || []);
    setSuppliers(supRes.data || []);
    setVariants(varRes.data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const addItemRow = () => {
    setForm((prev) => ({
      ...prev,
      items: [
        ...prev.items,
        { variant_id: '', product_name: '', quantity: '20', unit_price: '15', total: 300 },
      ],
    }));
  };

  const removeItemRow = (idx) => {
    if (form.items.length <= 1) return;
    setForm((prev) => ({
      ...prev,
      items: prev.items.filter((_, i) => i !== idx),
    }));
  };

  const handleVariantSelect = (idx, variantId) => {
    const v = variants.find((v) => v.id === variantId);
    if (!v) return;
    setForm((prev) => {
      const updated = [...prev.items];
      const prodName = `${v.products?.name || 'Produce'} (${v.weight}${v.unit})`;
      const cost = parseFloat(v.purchase_price) || 20;
      const qty = parseFloat(updated[idx].quantity) || 1;
      updated[idx] = {
        variant_id: v.id,
        product_name: prodName,
        quantity: String(qty),
        unit_price: String(cost),
        total: cost * qty,
      };
      return { ...prev, items: updated };
    });
  };

  const updateItemField = (idx, key, val) => {
    setForm((prev) => {
      const updated = [...prev.items];
      updated[idx] = { ...updated[idx], [key]: val };
      const qty = parseFloat(updated[idx].quantity) || 0;
      const price = parseFloat(updated[idx].unit_price) || 0;
      updated[idx].total = qty * price;
      return { ...prev, items: updated };
    });
  };

  const totalPoAmount = form.items.reduce((acc, it) => acc + (it.total || 0), 0);

  const savePo = async (e) => {
    e.preventDefault();
    setError('');
    setOk('');

    const sup = suppliers.find((s) => s.id === form.supplier_id);
    const poId = `PO-${Date.now().toString().slice(-8)}`;

    const { error: err } = await supabase.from('purchase_orders').insert({
      id: poId,
      supplier_id: form.supplier_id || null,
      supplier_name: sup?.name || 'Local Mandi Vendor',
      total_amount: totalPoAmount,
      status: 'pending',
      items: form.items,
      expected_delivery_date: form.expected_delivery_date || null,
      notes: form.notes || '',
    });

    if (err) {
      setError(`Failed to create PO: ${err.message}`);
      return;
    }

    setOk(`Purchase Order ${poId} created successfully!`);
    setOpen(false);
    load();
  };

  // Goods Received Note (GRN) Action: Inwards stock to live inventory
  const markAsReceived = async (po) => {
    if (po.status === 'received') return;
    if (!confirm(`Confirm Goods Received Note (GRN) for ${po.id}? This will immediately increment live inventory stock.`)) {
      return;
    }

    setError('');
    setOk('');

    const items = po.items || [];
    let updatedCount = 0;

    for (const it of items) {
      if (it.variant_id) {
        // Fetch current stock
        const { data: vData } = await supabase
          .from('product_variants')
          .select('id, product_id, stock_total')
          .eq('id', it.variant_id)
          .single();

        if (vData) {
          const current = vData.stock_total || 0;
          const incomingQty = parseFloat(it.quantity) || 0;
          const nextStock = current + incomingQty;
          await setVariantStock(vData.id, vData.product_id, nextStock);
          updatedCount++;
        }
      }
    }

    // Update PO status to received
    await supabase.from('purchase_orders').update({
      status: 'received',
      received_at: new Date().toISOString(),
    }).eq('id', po.id);

    setOk(`GRN Verified! Inwarded stock for ${updatedCount} items into live Inventory.`);
    load();
  };

  return (
    <div>
      <PageHead
        title="Purchase Orders & Goods Inwarding (GRN)"
        subtitle="Issue digital POs to farm vendors and auto-inward received inventory to live store stock"
        actions={
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => {
              setForm({
                supplier_id: suppliers[0]?.id || '',
                expected_delivery_date: new Date().toISOString().split('T')[0],
                notes: '',
                items: [
                  { variant_id: '', product_name: '', quantity: '50', unit_price: '20', total: 1000 },
                ],
              });
              setOpen(true);
            }}
          >
            + Create Purchase Order (PO)
          </button>
        }
      />

      {error && <div className="sz-alert error">{error}</div>}
      {ok && <div className="sz-alert success">{ok}</div>}

      <div className="sz-toolbar">
        <input
          className="grow"
          placeholder="Search by PO number or supplier name…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="sz-table-wrap">
        {loading ? (
          <div className="sz-empty">Loading purchase orders…</div>
        ) : pos.length === 0 ? (
          <Empty message="No purchase orders created yet" />
        ) : (
          <table className="sz-table">
            <thead>
              <tr>
                <th>PO Number</th>
                <th>Supplier / Farm</th>
                <th>Items Ordered</th>
                <th>Total Value</th>
                <th>Expected Date</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {pos.map((po) => {
                const items = po.items || [];
                return (
                  <tr key={po.id}>
                    <td>
                      <strong style={{ color: '#0c831f' }}>{po.id}</strong>
                      <div style={{ fontSize: 11, color: '#888' }}>
                        {new Date(po.created_at).toLocaleDateString()}
                      </div>
                    </td>
                    <td>
                      <strong>{po.supplier_name}</strong>
                    </td>
                    <td>
                      <span className="badge" style={{ background: '#f1f5f9' }}>
                        {items.length} items
                      </span>
                    </td>
                    <td style={{ fontWeight: 800 }}>{money(po.total_amount || 0)}</td>
                    <td style={{ fontSize: 12, color: '#475569' }}>
                      {po.expected_delivery_date || 'Immediate'}
                    </td>
                    <td>
                      <span
                        className="badge"
                        style={{
                          background:
                            po.status === 'received'
                              ? '#e7f6ea'
                              : po.status === 'approved'
                              ? '#e0f2fe'
                              : '#fff3e0',
                          color:
                            po.status === 'received'
                              ? '#0c831f'
                              : po.status === 'approved'
                              ? '#0284c7'
                              : '#ea580c',
                          fontWeight: 'bold',
                        }}
                      >
                        {po.status?.toUpperCase()}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        {po.status !== 'received' && (
                          <button
                            type="button"
                            className="btn btn-primary btn-sm"
                            onClick={() => markAsReceived(po)}
                            title="Verify Goods Inwarded & Increment Live Stock"
                          >
                            📥 Receive Stock (GRN)
                          </button>
                        )}
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => setViewPo(po)}>
                          👁️ View
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

      {/* Create Purchase Order Modal */}
      {open && (
        <Modal title="Create New Digital Purchase Order" onClose={() => setOpen(false)}>
          <form onSubmit={savePo} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                  Select Farm Vendor / Supplier *
                </label>
                <select
                  required
                  value={form.supplier_id}
                  onChange={(e) => setForm({ ...form, supplier_id: e.target.value })}
                >
                  <option value="">Choose Supplier</option>
                  {suppliers.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>
                  Expected Delivery Date
                </label>
                <input
                  type="date"
                  value={form.expected_delivery_date}
                  onChange={(e) => setForm({ ...form, expected_delivery_date: e.target.value })}
                />
              </div>
            </div>

            {/* Line Items Builder */}
            <div style={{ border: '1px solid #e2e8f0', borderRadius: 10, padding: 14 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                <div>
                  <strong style={{ fontSize: 13 }}>Inward Line Items</strong>
                  <div style={{ fontSize: 11, color: '#666' }}>Select produce items from catalog to order</div>
                </div>
                <button type="button" className="btn btn-ghost btn-sm" onClick={addItemRow}>
                  + Add Item Line
                </button>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {form.items.map((it, idx) => (
                  <div
                    key={idx}
                    style={{
                      display: 'grid',
                      gridTemplateColumns: '2fr 1fr 1fr 1fr 30px',
                      gap: 8,
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <select
                        required
                        value={it.variant_id}
                        onChange={(e) => handleVariantSelect(idx, e.target.value)}
                      >
                        <option value="">Select Catalog Produce</option>
                        {variants.map((v) => (
                          <option key={v.id} value={v.id}>
                            {v.products?.name} ({v.weight}{v.unit})
                          </option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <input
                        type="number"
                        placeholder="Quantity"
                        value={it.quantity}
                        onChange={(e) => updateItemField(idx, 'quantity', e.target.value)}
                      />
                    </div>
                    <div>
                      <input
                        type="number"
                        placeholder="Rate ₹"
                        value={it.unit_price}
                        onChange={(e) => updateItemField(idx, 'unit_price', e.target.value)}
                      />
                    </div>
                    <div style={{ fontWeight: 'bold', fontSize: 13, textAlign: 'right' }}>
                      {money(it.total || 0)}
                    </div>
                    <button
                      type="button"
                      onClick={() => removeItemRow(idx)}
                      style={{ color: '#ef4444', background: 'transparent', cursor: 'pointer' }}
                    >
                      ✕
                    </button>
                  </div>
                ))}
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', borderTop: '1px solid #e2e8f0', paddingTop: 10, marginTop: 10 }}>
                <span>Total PO Value: </span>
                <strong style={{ fontSize: 16, color: '#0c831f', marginLeft: 8 }}>
                  {money(totalPoAmount)}
                </strong>
              </div>
            </div>

            <div>
              <label style={{ fontSize: 12, fontWeight: 700, marginBottom: 4, display: 'block' }}>Special Notes</label>
              <textarea
                rows={2}
                placeholder="Delivery instructions for supplier..."
                value={form.notes}
                onChange={(e) => setForm({ ...form, notes: e.target.value })}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              <button type="button" className="btn btn-ghost" onClick={() => setOpen(false)}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                📑 Generate Purchase Order
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* View PO Details Modal */}
      {viewPo && (
        <Modal title={`Purchase Order: ${viewPo.id}`} onClose={() => setViewPo(null)}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, background: '#f8fafc', padding: 12, borderRadius: 10 }}>
              <div>
                <div style={{ fontSize: 11, color: '#64748b' }}>Supplier Name</div>
                <strong>{viewPo.supplier_name}</strong>
              </div>
              <div>
                <div style={{ fontSize: 11, color: '#64748b' }}>Status</div>
                <strong style={{ color: viewPo.status === 'received' ? '#0c831f' : '#ea580c' }}>
                  {viewPo.status?.toUpperCase()}
                </strong>
              </div>
            </div>

            <div style={{ border: '1px solid #e2e8f0', borderRadius: 8, overflow: 'hidden' }}>
              <table className="sz-table" style={{ margin: 0 }}>
                <thead>
                  <tr>
                    <th>Item</th>
                    <th>Qty Ordered</th>
                    <th>Unit Cost</th>
                    <th>Total</th>
                  </tr>
                </thead>
                <tbody>
                  {(viewPo.items || []).map((it, i) => (
                    <tr key={i}>
                      <td><strong>{it.product_name}</strong></td>
                      <td>{it.quantity}</td>
                      <td>{money(it.unit_price)}</td>
                      <td style={{ fontWeight: 'bold' }}>{money(it.total)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <span>Total PO Amount:</span>
                <strong style={{ fontSize: 16, color: '#0c831f', marginLeft: 8 }}>
                  {money(viewPo.total_amount)}
                </strong>
              </div>
              {viewPo.status !== 'received' && (
                <button
                  type="button"
                  className="btn btn-primary btn-sm"
                  onClick={() => {
                    setViewPo(null);
                    markAsReceived(viewPo);
                  }}
                >
                  📥 Confirm Goods Received (GRN)
                </button>
              )}
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
