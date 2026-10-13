import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';
import ImageUploader from './ImageUploader';

export default function InventoryManager() {
  const [activeTab, setActiveTab] = useState('products'); // 'products', 'subcategories', 'categories', 'settings'
  const [products, setProducts] = useState([]);
  const [subCategories, setSubCategories] = useState([]);
  const [categories, setCategories] = useState([]);
  const [settings, setSettings] = useState({
    delivery_fee: 0,
    tax_percentage: 0,
    service_charge: 0,
    packaging_fee: 0,
  });
  const [productSearch, setProductSearch] = useState('');
  
  // Loading states
  const [loading, setLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Form states
  const [productForm, setProductForm] = useState({
    id: '', name: '', category_id: '', sub_category_id: '', description: '',
    image_url: '', price: '', mrp: '', weight: '', unit: 'g', is_organic: false, status: 'active'
  });
  const [subCategoryForm, setSubCategoryForm] = useState({ id: '', name: '', category_id: '', image_url: '' });
  const [categoryForm, setCategoryForm] = useState({ id: '', name: '', icon: '', image_url: '', status: 'active' });
  const [editingItem, setEditingItem] = useState(null); // stores item being edited

  useEffect(() => {
    fetchCatalogData();
  }, []);

  const fetchCatalogData = async () => {
    setLoading(true);
    setError('');
    try {
      // 1. Fetch categories
      const { data: catData, error: catErr } = await supabase.from('categories').select('*').order('name');
      if (catErr) throw catErr;
      setCategories(catData || []);

      // 2. Fetch subcategories
      const { data: subData, error: subErr } = await supabase.from('sub_categories').select('*').order('name');
      if (subErr) throw subErr;
      setSubCategories(subData || []);

      // 3. Fetch products + variants
      const { data: prodData, error: prodErr } = await supabase
        .from('products')
        .select('*, categories(name), sub_categories(name), product_variants(*)');
      if (prodErr) throw prodErr;
      
      // Flatten products and variants for simpler list rendering
      const flattened = [];
      (prodData || []).forEach(p => {
        const variants = p.product_variants || [];
        if (variants.length === 0) {
          flattened.push({
            ...p,
            variant_id: p.id,
            price: 0,
            mrp: 0,
            weight: '',
            unit: 'pcs'
          });
        } else {
          variants.forEach(v => {
            flattened.push({
              ...p,
              variant_id: v.id,
              price: v.selling_price || 0,
              mrp: v.mrp || 0,
              weight: v.weight || '',
              unit: v.unit || 'pcs'
            });
          });
        }
      });
      setProducts(flattened);

      // 4. Fetch store settings
      const { data: settsData, error: settsErr } = await supabase.from('store_settings').select('*');
      if (!settsErr && settsData && settsData.length > 0) {
        setSettings({
          delivery_fee: 30,
          tax_percentage: 5,
          service_charge: 0,
          packaging_fee: 10,
          ...settsData[0],
        });
      } else {
        setSettings({ delivery_fee: 30, tax_percentage: 5, service_charge: 0, packaging_fee: 10 });
      }
    } catch (err) {
      setError(err.message || 'Failed to load catalog data.');
    } finally {
      setLoading(false);
    }
  };

  const handleProductSubmit = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    setError('');
    setSuccess('');

    try {
      const parentId = productForm.id || `prod_${Date.now()}`;
      
      // 1. Upsert product
      const { error: pErr } = await supabase.from('products').upsert({
        id: parentId,
        category_id: productForm.category_id,
        sub_category_id: productForm.sub_category_id || null,
        name: productForm.name,
        description: productForm.description,
        is_organic: productForm.is_organic,
        status: productForm.status,
        image_url: productForm.image_url
      });
      if (pErr) throw pErr;

      // 2. Upsert variant
      const variantId = editingItem ? editingItem.variant_id : `var_${Date.now()}`;
      const { error: vErr } = await supabase.from('product_variants').upsert({
        id: variantId,
        product_id: parentId,
        weight: productForm.weight,
        unit: productForm.unit,
        mrp: parseFloat(productForm.mrp || 0),
        selling_price: parseFloat(productForm.price || 0),
        sku: `SKU_${variantId.toUpperCase()}`
      });
      if (vErr) throw vErr;

      setSuccess('Product saved successfully!');
      resetForms();
      fetchCatalogData();
    } catch (err) {
      setError(err.message || 'Failed to save product.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleSubCategorySubmit = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    setError('');
    setSuccess('');

    try {
      const { error: err } = await supabase.from('sub_categories').upsert({
        id: subCategoryForm.id || `sub_${Date.now()}`,
        name: subCategoryForm.name,
        category_id: subCategoryForm.category_id,
        image_url: subCategoryForm.image_url
      });

      if (err) throw err;
      setSuccess('Sub-category saved successfully!');
      resetForms();
      fetchCatalogData();
    } catch (err) {
      setError(err.message || 'Failed to save subcategory.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleCategorySubmit = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    setError('');
    setSuccess('');

    try {
      const payload = {
        id: categoryForm.id || categoryForm.name.toLowerCase().replace(/\s+/g, '_'),
        name: categoryForm.name,
        icon: categoryForm.icon,
        status: categoryForm.status || 'active',
      };
      if (categoryForm.image_url) payload.image_url = categoryForm.image_url;

      const { error: err } = await supabase.from('categories').upsert(payload);

      if (err) throw err;
      setSuccess('Category saved successfully!');
      resetForms();
      fetchCatalogData();
    } catch (err) {
      setError(err.message || 'Failed to save category.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleSaveSettings = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    setError('');
    setSuccess('');

    try {
      const payload = {
        id: settings.id || 1,
        delivery_fee: parseFloat(settings.delivery_fee || 0),
        tax_percentage: parseFloat(settings.tax_percentage || 0),
        service_charge: parseFloat(settings.service_charge || 0),
        packaging_fee: parseFloat(settings.packaging_fee || 0),
      };

      let { error: err } = await supabase.from('store_settings').upsert(payload);

      // Retry without optional columns if schema is older
      if (err) {
        const fallback = {
          id: payload.id,
          delivery_fee: payload.delivery_fee,
          tax_percentage: payload.tax_percentage,
        };
        ({ error: err } = await supabase.from('store_settings').upsert(fallback));
        if (!err) {
          setSuccess('Delivery fee & tax saved. Add service_charge / packaging_fee columns in Supabase for full settings.');
          fetchCatalogData();
          return;
        }
      }

      if (err) throw err;
      setSuccess('Store charges & taxes updated successfully!');
      fetchCatalogData();
    } catch (err) {
      setError(err.message || 'Failed to update settings.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleToggleProductStatus = async (product) => {
    const newStatus = product.status === 'active' ? 'inactive' : 'active';
    try {
      const { error: err } = await supabase
        .from('products')
        .update({ status: newStatus })
        .eq('id', product.id);

      if (err) throw err;
      fetchCatalogData();
    } catch (err) {
      setError(err.message || 'Failed to update availability status.');
    }
  };

  const handleDeleteItem = async (type, id) => {
    if (!confirm('Are you sure you want to delete this item?')) return;
    setActionLoading(true);
    setError('');
    
    try {
      let table = 'products';
      if (type === 'subcategory') table = 'sub_categories';
      if (type === 'category') table = 'categories';

      const { error: err } = await supabase.from(table).delete().eq('id', id);
      if (err) throw err;

      setSuccess('Item deleted successfully!');
      fetchCatalogData();
    } catch (err) {
      setError(err.message || 'Failed to delete item.');
    } finally {
      setActionLoading(false);
    }
  };

  const startEditProduct = (p) => {
    setEditingItem(p);
    setProductForm({
      id: p.id,
      name: p.name,
      category_id: p.category_id,
      sub_category_id: p.sub_category_id || '',
      description: p.description || '',
      image_url: p.image_url || '',
      price: p.price,
      mrp: p.mrp,
      weight: p.weight,
      unit: p.unit,
      is_organic: p.is_organic || false,
      status: p.status
    });
  };

  const startEditSubCategory = (sub) => {
    setEditingItem(sub);
    setSubCategoryForm({
      id: sub.id,
      name: sub.name,
      category_id: sub.category_id,
      image_url: sub.image_url || ''
    });
  };

  const startEditCategory = (cat) => {
    setEditingItem(cat);
    setCategoryForm({
      id: cat.id,
      name: cat.name,
      icon: cat.icon || '',
      image_url: cat.image_url || '',
      status: cat.status || 'active',
    });
  };

  const resetForms = () => {
    setEditingItem(null);
    setProductForm({
      id: '', name: '', category_id: '', sub_category_id: '', description: '',
      image_url: '', price: '', mrp: '', weight: '', unit: 'g', is_organic: false, status: 'active'
    });
    setSubCategoryForm({ id: '', name: '', category_id: '', image_url: '' });
    setCategoryForm({ id: '', name: '', icon: '', image_url: '', status: 'active' });
  };

  const visibleProducts = products.filter((p) => {
    const q = productSearch.trim().toLowerCase();
    if (!q) return true;
    return (
      p.name?.toLowerCase().includes(q) ||
      p.categories?.name?.toLowerCase().includes(q) ||
      p.sub_categories?.name?.toLowerCase().includes(q)
    );
  });

  // CSV Bulk Upload Reader
  const handleCSVUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (evt) => {
      const text = evt.target.result;
      const lines = text.split('\n');
      const headers = lines[0].split(',').map(h => h.trim().toLowerCase());
      
      // Expected columns: name, category_id, sub_category_id, price, mrp, weight, unit, description, image_url
      setLoading(true);
      setError('');
      setSuccess('');

      try {
        let successCount = 0;
        for (let i = 1; i < lines.length; i++) {
          if (!lines[i].trim()) continue;
          const cols = lines[i].split(',').map(c => c.trim());
          
          // Map index to headers
          const name = cols[headers.indexOf('name')];
          const category_id = cols[headers.indexOf('category_id')];
          const sub_category_id = cols[headers.indexOf('sub_category_id')];
          const price = parseFloat(cols[headers.indexOf('price')] || 0);
          const mrp = parseFloat(cols[headers.indexOf('mrp')] || 0);
          const weight = cols[headers.indexOf('weight')] || '';
          const unit = cols[headers.indexOf('unit')] || 'g';
          const description = cols[headers.indexOf('description')] || '';
          const image_url = cols[headers.indexOf('image_url')] || '';

          if (!name || !category_id) continue;

          // Perform upsert
          const parentId = `prod_csv_${Date.now()}_${i}`;
          await supabase.from('products').upsert({
            id: parentId,
            category_id,
            sub_category_id: sub_category_id || null,
            name,
            description,
            is_organic: false,
            status: 'active',
            image_url
          });

          const variantId = `var_csv_${Date.now()}_${i}`;
          await supabase.from('product_variants').upsert({
            id: variantId,
            product_id: parentId,
            weight,
            unit,
            mrp,
            selling_price: price,
            sku: `SKU_${variantId.toUpperCase()}`
          });
          successCount++;
        }
        setSuccess(`Successfully imported ${successCount} products!`);
        fetchCatalogData();
      } catch (err) {
        setError('Error parsing CSV. Please check columns format.');
      } finally {
        setLoading(false);
      }
    };
    reader.readAsText(file);
  };

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <div>
          <h1 style={styles.title}>Menu & Item Management</h1>
          <p style={styles.subtitle}>Manage your store categories, sub-categories, and bulk CSV updates</p>
        </div>
        <div style={styles.csvBox}>
          <label style={styles.csvLabel}>Bulk CSV Upload</label>
          <input
            type="file"
            accept=".csv"
            onChange={handleCSVUpload}
            style={styles.csvInput}
          />
        </div>
      </div>

      {error && <div style={styles.errorAlert}>{error}</div>}
      {success && <div style={styles.successAlert}>{success}</div>}

      {/* Tabs */}
      <div style={styles.tabContainer}>
        {['products', 'subcategories', 'categories', 'settings'].map(tab => (
          <button
            key={tab}
            onClick={() => { setActiveTab(tab); resetForms(); }}
            style={{
              ...styles.tabButton,
              background: activeTab === tab ? 'var(--primary)' : 'transparent',
              color: activeTab === tab ? '#ffffff' : 'var(--text-main)',
            }}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </div>

      <div style={styles.contentGrid}>
        {/* Forms column */}
        {activeTab !== 'settings' && (
          <div style={styles.formContainer} className="glass">
            <h3 style={styles.formTitle}>
              {editingItem ? 'Edit Item Details' : 'Add New Item'}
            </h3>
            
            {activeTab === 'products' && (
              <form onSubmit={handleProductSubmit} style={styles.form}>
                <input
                  type="text"
                  required
                  placeholder="Product Name"
                  value={productForm.name}
                  onChange={(e) => setProductForm({ ...productForm, name: e.target.value })}
                />
                <select
                  required
                  value={productForm.category_id}
                  onChange={(e) => setProductForm({ ...productForm, category_id: e.target.value })}
                >
                  <option value="">Select Parent Category</option>
                  {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
                <select
                  value={productForm.sub_category_id}
                  onChange={(e) => setProductForm({ ...productForm, sub_category_id: e.target.value })}
                >
                  <option value="">Select Sub-Category (Optional)</option>
                  {subCategories
                    .filter(s => s.category_id === productForm.category_id)
                    .map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
                <input
                  type="text"
                  placeholder="Description"
                  value={productForm.description}
                  onChange={(e) => setProductForm({ ...productForm, description: e.target.value })}
                />
                <ImageUploader
                  label="Product image"
                  folder={`Products/${productForm.category_id || 'General'}`}
                  value={productForm.image_url}
                  onChange={(url) => setProductForm({ ...productForm, image_url: url })}
                />
                <div style={styles.row}>
                  <input
                    type="number"
                    required
                    placeholder="MRP Price (₹)"
                    value={productForm.mrp}
                    onChange={(e) => setProductForm({ ...productForm, mrp: e.target.value })}
                  />
                  <input
                    type="number"
                    required
                    placeholder="Selling Price (₹)"
                    value={productForm.price}
                    onChange={(e) => setProductForm({ ...productForm, price: e.target.value })}
                  />
                </div>
                <div style={styles.row}>
                  <input
                    type="text"
                    required
                    placeholder="Weight (e.g. 500, 1)"
                    value={productForm.weight}
                    onChange={(e) => setProductForm({ ...productForm, weight: e.target.value })}
                  />
                  <select
                    required
                    value={productForm.unit}
                    onChange={(e) => setProductForm({ ...productForm, unit: e.target.value })}
                  >
                    <option value="g">g</option>
                    <option value="kg">kg</option>
                    <option value="ml">ml</option>
                    <option value="liter">liter</option>
                    <option value="pcs">pcs</option>
                    <option value="dozen">dozen</option>
                  </select>
                </div>
                <div style={styles.checkboxRow}>
                  <input
                    type="checkbox"
                    id="is_organic"
                    checked={productForm.is_organic}
                    onChange={(e) => setProductForm({ ...productForm, is_organic: e.target.checked })}
                    style={{ width: 'auto' }}
                  />
                  <label htmlFor="is_organic" style={{ fontSize: '14px', fontWeight: '600' }}>Organic Product</label>
                </div>
                <div style={styles.btnRow}>
                  <button type="submit" disabled={actionLoading} style={styles.saveBtn}>
                    {actionLoading ? 'Saving...' : 'Save Product'}
                  </button>
                  {editingItem && (
                    <button type="button" onClick={resetForms} style={styles.cancelBtn}>
                      Cancel
                    </button>
                  )}
                </div>
              </form>
            )}

            {activeTab === 'subcategories' && (
              <form onSubmit={handleSubCategorySubmit} style={styles.form}>
                <input
                  type="text"
                  required
                  placeholder="Subcategory Name"
                  value={subCategoryForm.name}
                  onChange={(e) => setSubCategoryForm({ ...subCategoryForm, name: e.target.value })}
                />
                <select
                  required
                  value={subCategoryForm.category_id}
                  onChange={(e) => setSubCategoryForm({ ...subCategoryForm, category_id: e.target.value })}
                >
                  <option value="">Select Category</option>
                  {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
                <ImageUploader
                  label="Sub-category image"
                  folder="Sub Categories"
                  value={subCategoryForm.image_url}
                  onChange={(url) => setSubCategoryForm({ ...subCategoryForm, image_url: url })}
                />
                <div style={styles.btnRow}>
                  <button type="submit" disabled={actionLoading} style={styles.saveBtn}>
                    {actionLoading ? 'Saving...' : 'Save'}
                  </button>
                  {editingItem && (
                    <button type="button" onClick={resetForms} style={styles.cancelBtn}>
                      Cancel
                    </button>
                  )}
                </div>
              </form>
            )}

            {activeTab === 'categories' && (
              <form onSubmit={handleCategorySubmit} style={styles.form}>
                <input
                  type="text"
                  required
                  placeholder="Category Name"
                  value={categoryForm.name}
                  onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })}
                />
                <input
                  type="text"
                  placeholder="Icon Name (e.g. apple, leaf)"
                  value={categoryForm.icon}
                  onChange={(e) => setCategoryForm({ ...categoryForm, icon: e.target.value })}
                />
                <ImageUploader
                  label="Category image"
                  folder="Categories"
                  value={categoryForm.image_url}
                  onChange={(url) => setCategoryForm({ ...categoryForm, image_url: url })}
                />
                <select
                  value={categoryForm.status}
                  onChange={(e) => setCategoryForm({ ...categoryForm, status: e.target.value })}
                >
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </select>
                <div style={styles.btnRow}>
                  <button type="submit" disabled={actionLoading} style={styles.saveBtn}>
                    {actionLoading ? 'Saving...' : 'Save'}
                  </button>
                  {editingItem && (
                    <button type="button" onClick={resetForms} style={styles.cancelBtn}>
                      Cancel
                    </button>
                  )}
                </div>
              </form>
            )}
          </div>
        )}

        {/* Display / Settings column */}
        <div style={{ flex: 1 }}>
          {activeTab === 'products' && (
            <div>
              <div style={{ marginBottom: 14 }}>
                <input
                  placeholder="Search products…"
                  value={productSearch}
                  onChange={(e) => setProductSearch(e.target.value)}
                  style={{ maxWidth: 320 }}
                />
              </div>
            <div className="admin-table-container">
              {loading ? (
                <div style={styles.loading}>Loading catalog...</div>
              ) : (
                <table>
                  <thead>
                    <tr>
                      <th>Image</th>
                      <th>Product</th>
                      <th>Category</th>
                      <th>Subcategory</th>
                      <th>Weight</th>
                      <th>Price</th>
                      <th>Status</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {visibleProducts.map(p => (
                      <tr key={p.variant_id}>
                        <td>
                          {p.image_url ? (
                            <img src={p.image_url} alt="" style={styles.tableImg} />
                          ) : (
                            <div style={styles.placeholderImg}>N/A</div>
                          )}
                        </td>
                        <td style={{ fontWeight: '700' }}>{p.name}</td>
                        <td>{p.categories?.name || 'All'}</td>
                        <td>{p.sub_categories?.name || '-'}</td>
                        <td>{`${p.weight} ${p.unit}`}</td>
                        <td style={{ fontWeight: '700' }}>₹{p.price} <span style={styles.strike}>₹{p.mrp}</span></td>
                        <td>
                          <button
                            onClick={() => handleToggleProductStatus(p)}
                            style={{
                              ...styles.statusBtn,
                              background: p.status === 'active' ? '#e8f5e9' : '#ffebee',
                              color: p.status === 'active' ? 'var(--accent-color)' : 'var(--danger-color)',
                            }}
                          >
                            {p.status === 'active' ? 'In Stock' : 'Out of Stock'}
                          </button>
                        </td>
                        <td>
                          <div style={styles.actions}>
                            <button onClick={() => startEditProduct(p)} style={styles.editBtn}>Edit</button>
                            <button onClick={() => handleDeleteItem('product', p.id)} style={styles.deleteBtn}>Delete</button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
            </div>
          )}

          {activeTab === 'subcategories' && (
            <div className="admin-table-container">
              {loading ? (
                <div style={styles.loading}>Loading...</div>
              ) : (
                <table>
                  <thead>
                    <tr>
                      <th>Image</th>
                      <th>Sub-category Name</th>
                      <th>Parent Category ID</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {subCategories.map(sub => (
                      <tr key={sub.id}>
                        <td>
                          {sub.image_url ? (
                            <img src={sub.image_url} alt="" style={styles.tableImg} />
                          ) : (
                            <div style={styles.placeholderImg}>N/A</div>
                          )}
                        </td>
                        <td style={{ fontWeight: '700' }}>{sub.name}</td>
                        <td>{sub.category_id}</td>
                        <td>
                          <div style={styles.actions}>
                            <button onClick={() => startEditSubCategory(sub)} style={styles.editBtn}>Edit</button>
                            <button onClick={() => handleDeleteItem('subcategory', sub.id)} style={styles.deleteBtn}>Delete</button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          )}

          {activeTab === 'categories' && (
            <div className="admin-table-container">
              {loading ? (
                <div style={styles.loading}>Loading...</div>
              ) : (
                <table>
                  <thead>
                    <tr>
                      <th>Category Name</th>
                      <th>Icon ID</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {categories.map(cat => (
                      <tr key={cat.id}>
                        <td style={{ fontWeight: '700' }}>{cat.name}</td>
                        <td>{cat.icon || '-'}</td>
                        <td>
                          <div style={styles.actions}>
                            <button onClick={() => startEditCategory(cat)} style={styles.editBtn}>Edit</button>
                            <button onClick={() => handleDeleteItem('category', cat.id)} style={styles.deleteBtn}>Delete</button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          )}

          {activeTab === 'settings' && (
            <div style={styles.settingsBox} className="glass">
              <h3 style={styles.formTitle}>Store Charges & Taxes</h3>
              <form onSubmit={handleSaveSettings} style={styles.form}>
                <div style={styles.field}>
                  <label style={styles.label}>Delivery Fee (₹)</label>
                  <input
                    type="number"
                    required
                    value={settings.delivery_fee}
                    onChange={(e) => setSettings({ ...settings, delivery_fee: e.target.value })}
                  />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Service Charge (₹)</label>
                  <input
                    type="number"
                    value={settings.service_charge ?? 0}
                    onChange={(e) => setSettings({ ...settings, service_charge: e.target.value })}
                  />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Packaging Fee (₹)</label>
                  <input
                    type="number"
                    value={settings.packaging_fee ?? 0}
                    onChange={(e) => setSettings({ ...settings, packaging_fee: e.target.value })}
                  />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Tax / GST (%)</label>
                  <input
                    type="number"
                    required
                    value={settings.tax_percentage}
                    onChange={(e) => setSettings({ ...settings, tax_percentage: e.target.value })}
                  />
                </div>
                <button type="submit" disabled={actionLoading} style={styles.saveBtn}>
                  {actionLoading ? 'Saving Settings...' : 'Save Config'}
                </button>
              </form>
            </div>
          )}
        </div>
      </div>
    </div>
  );
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
  csvBox: {
    background: 'rgba(25, 118, 210, 0.05)',
    border: '1px dashed var(--primary)',
    padding: '12px 20px',
    borderRadius: 'var(--radius-md)',
    textAlign: 'center',
  },
  csvLabel: {
    display: 'block',
    fontSize: '11px',
    fontWeight: '700',
    color: 'var(--primary)',
    textTransform: 'uppercase',
    marginBottom: '6px',
  },
  csvInput: {
    border: 'none',
    padding: '0',
    background: 'none',
    fontSize: '12px',
    cursor: 'pointer',
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
  tabContainer: {
    display: 'flex',
    gap: '10px',
    marginBottom: '25px',
    borderBottom: '1px solid var(--border-color)',
    paddingBottom: '12px',
  },
  tabButton: {
    padding: '10px 20px',
    borderRadius: 'var(--radius-sm)',
    fontSize: '14px',
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
  row: {
    display: 'flex',
    gap: '12px',
  },
  checkboxRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    marginTop: '6px',
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
  tableImg: {
    width: '40px',
    height: '40px',
    objectFit: 'contain',
    borderRadius: 'var(--radius-sm)',
    background: '#f8f9fa',
    border: '1px solid var(--border-color)',
  },
  placeholderImg: {
    width: '40px',
    height: '40px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#cfd8dc',
    color: '#ffffff',
    fontSize: '10px',
    fontWeight: '700',
    borderRadius: 'var(--radius-sm)',
  },
  strike: {
    textDecoration: 'line-through',
    color: 'var(--text-muted)',
    fontSize: '12px',
    marginLeft: '6px',
  },
  statusBtn: {
    padding: '6px 12px',
    borderRadius: '20px',
    fontSize: '12px',
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
  settingsBox: {
    maxWidth: '500px',
    borderRadius: 'var(--radius-md)',
    padding: '30px',
    boxShadow: 'var(--shadow-sm)',
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
};
