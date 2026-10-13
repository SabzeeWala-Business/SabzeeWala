import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '../supabase';
import { orderGrandTotal } from '../config';

export default function CustomerManager() {
  const [activeTab, setActiveTab] = useState('customers');
  const [customers, setCustomers] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [companies, setCompanies] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [userOrders, setUserOrders] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [employeeForm, setEmployeeForm] = useState({
    name: '',
    role: 'Delivery Agent',
    phone: '',
    status: 'active',
  });
  const [companyForm, setCompanyForm] = useState({
    name: '',
    contact_person: '',
    phone: '',
    email: '',
    gstin: '',
    address: '',
  });
  const [actionLoading, setActionLoading] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    fetchUsersData();
  }, [activeTab]);

  const phoneOf = (profile) => profile.phone || profile.mobile || '—';

  const fetchUsersData = async () => {
    setLoading(true);
    setMessage('');
    try {
      if (activeTab === 'customers') {
        const { data, error } = await supabase
          .from('profiles')
          .select('*, orders(id, order_status, created_at, total, delivery_fee, order_items(price, quantity))')
          .order('name');

        if (error) throw error;

        const processed = (data || [])
          .filter((p) => p.id !== 'system_inventory' && p.role !== 'admin')
          .map((profile) => {
            const orders = profile.orders || [];
            const completed = orders.filter(
              (o) => (o.order_status || '').toLowerCase() === 'delivered'
            );
            let totalSpent = 0;
            completed.forEach((o) => {
              totalSpent += orderGrandTotal(o);
            });
            return {
              ...profile,
              orderCount: orders.length,
              completedCount: completed.length,
              totalSpent,
            };
          });

        setCustomers(processed);
      } else if (activeTab === 'employees') {
        const { data, error } = await supabase.from('delivery_partners').select('*').order('name');
        if (error) {
          setEmployees([]);
          setMessage('delivery_partners table missing or inaccessible.');
        } else {
          setEmployees(data || []);
        }
      } else {
        const { data, error } = await supabase.from('companies').select('*').order('name');
        if (error) {
          setCompanies([]);
          setMessage('Companies table missing. Create it in Supabase to manage B2B accounts.');
        } else {
          setCompanies(data || []);
        }
      }
    } catch (err) {
      console.error(err);
      setMessage(err.message || 'Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const handleToggleBlockUser = async (user) => {
    const isBlocked = user.status === 'blocked';
    const newStatus = isBlocked ? 'active' : 'blocked';
    if (!confirm(`${isBlocked ? 'Unblock' : 'Block'} ${user.name || 'this user'}?`)) return;

    try {
      const { error } = await supabase
        .from('profiles')
        .update({ status: newStatus })
        .eq('id', user.id);
      if (error) throw error;
      fetchUsersData();
      if (selectedUser?.id === user.id) {
        setSelectedUser((prev) => ({ ...prev, status: newStatus }));
      }
    } catch (err) {
      alert(err.message || 'Failed to update status');
    }
  };

  const fetchSelectedUserOrders = async (user) => {
    setSelectedUser(user);
    setUserOrders([]);
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });
      if (error) throw error;
      setUserOrders(data || []);
    } catch (err) {
      console.error(err);
    }
  };

  const handleAddEmployee = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    try {
      const { error } = await supabase.from('delivery_partners').insert([
        {
          id: `dp_${Date.now()}`,
          name: employeeForm.name,
          role: employeeForm.role,
          phone: employeeForm.phone,
          status: employeeForm.status,
        },
      ]);
      if (error) throw error;
      setEmployeeForm({ name: '', role: 'Delivery Agent', phone: '', status: 'active' });
      fetchUsersData();
    } catch (err) {
      alert(err.message || 'Could not save partner. Ensure delivery_partners table exists.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleAddCompany = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    try {
      const { error } = await supabase.from('companies').insert([
        {
          id: `co_${Date.now()}`,
          ...companyForm,
          status: 'active',
        },
      ]);
      if (error) throw error;
      setCompanyForm({
        name: '',
        contact_person: '',
        phone: '',
        email: '',
        gstin: '',
        address: '',
      });
      fetchUsersData();
    } catch (err) {
      alert(err.message || 'Could not save company. Ensure the companies table exists.');
    } finally {
      setActionLoading(false);
    }
  };

  const filteredCustomers = useMemo(() => {
    const q = searchTerm.trim().toLowerCase();
    if (!q) return customers;
    return customers.filter(
      (c) =>
        c.name?.toLowerCase().includes(q) ||
        String(phoneOf(c)).includes(q) ||
        c.email?.toLowerCase().includes(q)
    );
  }, [customers, searchTerm]);

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>Customers, Staff & Companies</h1>
      <p style={styles.subtitle}>
        Spend profiles, order history, block/unblock, employees, and B2B company records
      </p>

      <div style={styles.tabContainer}>
        {[
          ['customers', 'Registered Customers'],
          ['employees', 'Staff & Employees'],
          ['companies', 'Companies'],
        ].map(([id, label]) => (
          <button
            key={id}
            type="button"
            onClick={() => {
              setActiveTab(id);
              setSelectedUser(null);
            }}
            style={{
              ...styles.tabButton,
              background: activeTab === id ? 'var(--primary)' : 'transparent',
              color: activeTab === id ? '#fff' : 'var(--text-main)',
            }}
          >
            {label}
          </button>
        ))}
      </div>

      {message && <div style={styles.infoAlert}>{message}</div>}

      {activeTab === 'customers' && (
        <div style={styles.mainGrid}>
          <div style={{ flex: 1, minWidth: 280 }}>
            <div style={styles.searchBar}>
              <input
                placeholder="Search by name, phone, or email…"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            <div className="admin-table-container">
              {loading ? (
                <div style={styles.loading}>Loading customers…</div>
              ) : (
                <table>
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Phone</th>
                      <th>Orders</th>
                      <th>Spend</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredCustomers.map((c) => (
                      <tr
                        key={c.id}
                        onClick={() => fetchSelectedUserOrders(c)}
                        style={{
                          cursor: 'pointer',
                          background:
                            selectedUser?.id === c.id
                              ? 'rgba(25, 118, 210, 0.05)'
                              : 'transparent',
                        }}
                      >
                        <td style={{ fontWeight: 700 }}>{c.name || 'Anonymous'}</td>
                        <td>{phoneOf(c)}</td>
                        <td>{c.orderCount}</td>
                        <td style={{ fontWeight: 700, color: 'var(--primary)' }}>
                          ₹{c.totalSpent.toLocaleString()}
                        </td>
                        <td>
                          <span
                            style={{
                              ...styles.statusTag,
                              background: c.status === 'blocked' ? '#ffebee' : '#e8f5e9',
                              color:
                                c.status === 'blocked'
                                  ? 'var(--danger-color)'
                                  : 'var(--accent-color)',
                            }}
                          >
                            {c.status === 'blocked' ? 'Blocked' : 'Active'}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>

          <div style={styles.profileSection} className="glass">
            {selectedUser ? (
              <div>
                <div style={styles.profileHeader}>
                  <h3>{selectedUser.name || 'Customer'}</h3>
                  <button
                    type="button"
                    onClick={() => handleToggleBlockUser(selectedUser)}
                    style={{
                      ...styles.actionBtn,
                      background: selectedUser.status === 'blocked' ? '#e8f5e9' : '#ffebee',
                      color:
                        selectedUser.status === 'blocked'
                          ? 'var(--accent-color)'
                          : 'var(--danger-color)',
                    }}
                  >
                    {selectedUser.status === 'blocked' ? 'Unblock' : 'Block'}
                  </button>
                </div>
                <p style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 12 }}>
                  {phoneOf(selectedUser)}
                  {selectedUser.email ? ` · ${selectedUser.email}` : ''}
                </p>
                <div style={styles.statsCardGrid}>
                  <div style={styles.statsCard}>
                    <div style={styles.statsLabel}>Orders</div>
                    <div style={styles.statsVal}>{selectedUser.orderCount}</div>
                  </div>
                  <div style={styles.statsCard}>
                    <div style={styles.statsLabel}>Net spend</div>
                    <div style={styles.statsVal}>₹{selectedUser.totalSpent.toLocaleString()}</div>
                  </div>
                </div>
                <h4 style={styles.logsHeader}>Order history</h4>
                <div style={styles.ordersLogList}>
                  {userOrders.length === 0 ? (
                    <div style={styles.noLogs}>No orders yet.</div>
                  ) : (
                    userOrders.map((o) => (
                      <div key={o.id} style={styles.logCard}>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <strong>
                            {o.order_number || `#${String(o.id).slice(-6).toUpperCase()}`}
                          </strong>
                          <span>₹{orderGrandTotal(o).toFixed(0)}</span>
                        </div>
                        <div
                          style={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            fontSize: 12,
                            color: 'var(--text-muted)',
                            marginTop: 4,
                          }}
                        >
                          <span>{new Date(o.created_at).toLocaleDateString()}</span>
                          <span>{(o.order_status || '—').toUpperCase()}</span>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            ) : (
              <div style={styles.emptyDetail}>
                Select a customer to view spend profile and order history.
              </div>
            )}
          </div>
        </div>
      )}

      {activeTab === 'employees' && (
        <div style={styles.mainGrid}>
          <div style={styles.formContainer} className="glass">
            <h3 style={styles.formTitle}>Add staff member</h3>
            <form onSubmit={handleAddEmployee} style={styles.form}>
              <input
                required
                placeholder="Employee name"
                value={employeeForm.name}
                onChange={(e) => setEmployeeForm({ ...employeeForm, name: e.target.value })}
              />
              <select
                value={employeeForm.role}
                onChange={(e) => setEmployeeForm({ ...employeeForm, role: e.target.value })}
              >
                <option value="Delivery Agent">Delivery Agent</option>
                <option value="Store Manager">Store Manager</option>
                <option value="Warehouse Associate">Warehouse Associate</option>
                <option value="Packer">Packer</option>
              </select>
              <input
                required
                type="tel"
                placeholder="Phone"
                value={employeeForm.phone}
                onChange={(e) => setEmployeeForm({ ...employeeForm, phone: e.target.value })}
              />
              <button type="submit" disabled={actionLoading} style={styles.submitBtn}>
                {actionLoading ? 'Saving…' : 'Register employee'}
              </button>
            </form>
          </div>
          <div style={{ flex: 1 }} className="admin-table-container">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Role</th>
                  <th>Phone</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {employees.map((emp) => (
                  <tr key={emp.id}>
                    <td style={{ fontWeight: 700 }}>{emp.name}</td>
                    <td>{emp.role}</td>
                    <td>{emp.phone}</td>
                    <td>
                      <span
                        style={{
                          ...styles.statusTag,
                          background: emp.status === 'active' ? '#e8f5e9' : '#ffebee',
                          color:
                            emp.status === 'active'
                              ? 'var(--accent-color)'
                              : 'var(--danger-color)',
                        }}
                      >
                        {(emp.status || 'active').toUpperCase()}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {activeTab === 'companies' && (
        <div style={styles.mainGrid}>
          <div style={styles.formContainer} className="glass">
            <h3 style={styles.formTitle}>Add company</h3>
            <form onSubmit={handleAddCompany} style={styles.form}>
              <input
                required
                placeholder="Company name"
                value={companyForm.name}
                onChange={(e) => setCompanyForm({ ...companyForm, name: e.target.value })}
              />
              <input
                placeholder="Contact person"
                value={companyForm.contact_person}
                onChange={(e) =>
                  setCompanyForm({ ...companyForm, contact_person: e.target.value })
                }
              />
              <input
                type="tel"
                placeholder="Phone"
                value={companyForm.phone}
                onChange={(e) => setCompanyForm({ ...companyForm, phone: e.target.value })}
              />
              <input
                type="email"
                placeholder="Email"
                value={companyForm.email}
                onChange={(e) => setCompanyForm({ ...companyForm, email: e.target.value })}
              />
              <input
                placeholder="GSTIN"
                value={companyForm.gstin}
                onChange={(e) => setCompanyForm({ ...companyForm, gstin: e.target.value })}
              />
              <textarea
                placeholder="Address"
                rows={2}
                value={companyForm.address}
                onChange={(e) => setCompanyForm({ ...companyForm, address: e.target.value })}
              />
              <button type="submit" disabled={actionLoading} style={styles.submitBtn}>
                {actionLoading ? 'Saving…' : 'Save company'}
              </button>
            </form>
          </div>
          <div style={{ flex: 1 }} className="admin-table-container">
            <table>
              <thead>
                <tr>
                  <th>Company</th>
                  <th>Contact</th>
                  <th>Phone</th>
                  <th>GSTIN</th>
                </tr>
              </thead>
              <tbody>
                {companies.map((co) => (
                  <tr key={co.id}>
                    <td style={{ fontWeight: 700 }}>{co.name}</td>
                    <td>{co.contact_person || '—'}</td>
                    <td>{co.phone || '—'}</td>
                    <td>{co.gstin || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

const styles = {
  container: { padding: 30 },
  title: { fontSize: 22, fontWeight: 800 },
  subtitle: { fontSize: 14, color: 'var(--text-muted)', marginTop: 4, marginBottom: 24 },
  tabContainer: {
    display: 'flex',
    gap: 10,
    marginBottom: 20,
    borderBottom: '1px solid var(--border-color)',
    paddingBottom: 12,
    flexWrap: 'wrap',
  },
  tabButton: { padding: '10px 18px', borderRadius: 6, fontSize: 14 },
  infoAlert: {
    background: '#e3f2fd',
    color: '#1565c0',
    padding: '10px 14px',
    borderRadius: 8,
    fontSize: 13,
    marginBottom: 16,
  },
  mainGrid: { display: 'flex', gap: 24, alignItems: 'flex-start', flexWrap: 'wrap' },
  searchBar: { marginBottom: 16 },
  statusTag: {
    padding: '4px 10px',
    borderRadius: 20,
    fontSize: 11,
    fontWeight: 700,
    display: 'inline-block',
  },
  profileSection: {
    width: 380,
    maxWidth: '100%',
    borderRadius: 12,
    padding: 24,
    boxShadow: 'var(--shadow-sm)',
    minHeight: 400,
  },
  profileHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderBottom: '1px solid var(--border-color)',
    paddingBottom: 12,
    marginBottom: 8,
  },
  actionBtn: { padding: '8px 14px', borderRadius: 6, fontSize: 12 },
  statsCardGrid: { display: 'flex', gap: 12, marginBottom: 18 },
  statsCard: {
    flex: 1,
    background: 'rgba(25, 118, 210, 0.03)',
    border: '1px solid rgba(25, 118, 210, 0.1)',
    borderRadius: 10,
    padding: 12,
    textAlign: 'center',
  },
  statsLabel: {
    fontSize: 10,
    color: 'var(--text-muted)',
    textTransform: 'uppercase',
    fontWeight: 700,
    marginBottom: 4,
  },
  statsVal: { fontSize: 18, fontWeight: 800, color: 'var(--primary)' },
  logsHeader: { fontSize: 13, fontWeight: 700, marginBottom: 12 },
  ordersLogList: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
    maxHeight: 280,
    overflowY: 'auto',
  },
  logCard: {
    padding: '10px 14px',
    background: 'var(--bg-card)',
    borderRadius: 8,
    border: '1px solid var(--border-color)',
    fontSize: 13,
  },
  noLogs: { padding: 20, color: 'var(--text-muted)', fontSize: 13, textAlign: 'center' },
  emptyDetail: {
    minHeight: 280,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: 'var(--text-muted)',
    fontSize: 14,
    textAlign: 'center',
    padding: 40,
  },
  formContainer: {
    width: 320,
    maxWidth: '100%',
    borderRadius: 12,
    padding: 24,
    boxShadow: 'var(--shadow-sm)',
  },
  formTitle: {
    fontSize: 15,
    fontWeight: 800,
    marginBottom: 18,
    borderBottom: '1px solid var(--border-color)',
    paddingBottom: 10,
  },
  form: { display: 'flex', flexDirection: 'column', gap: 14 },
  submitBtn: {
    background: 'var(--primary)',
    color: '#fff',
    padding: 12,
    borderRadius: 6,
    fontSize: 13,
  },
  loading: { padding: 40, textAlign: 'center', color: 'var(--text-muted)', fontWeight: 600 },
};
