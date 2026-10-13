import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../supabase';
import { PageHead, Empty, Modal } from '../components/ui';
import {
  MODULES,
  DEFAULT_ROLES,
  normalizeRole,
  isSuperAdmin,
  isAdminOrHigher,
  getRoleBadge,
  getRoleDisplayName,
} from '../utils/rbac';

export default function AdminAccessPage({ currentAdmin }) {
  const [activeTab, setActiveTab] = useState('admins'); // 'admins' | 'roles' | 'security'
  const [adminUsers, setAdminUsers] = useState([]);
  const [rolesList, setRolesList] = useState([]);
  const [registeredUsers, setRegisteredUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [alertMsg, setAlertMsg] = useState({ type: '', text: '' });

  // Modal states
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [grantModalOpen, setGrantModalOpen] = useState(false);
  const [editAdminModal, setEditAdminModal] = useState(null);
  const [customRoleModal, setCustomRoleModal] = useState(false);
  const [editingRole, setEditingRole] = useState(null);

  // Form states
  const [createForm, setCreateForm] = useState({
    name: '',
    email: '',
    mobile: '',
    role: 'operations_manager',
    status: 'active',
  });

  const [grantForm, setGrantForm] = useState({
    userId: '',
    role: 'operations_manager',
    searchUser: '',
  });

  const [roleForm, setRoleForm] = useState({
    name: '',
    displayName: '',
    description: '',
    permissions: [],
  });

  const canManageAdmins = useMemo(() => {
    return isAdminOrHigher(currentAdmin?.role);
  }, [currentAdmin]);

  // Load all admin users, roles, and candidate users
  const loadData = async () => {
    setLoading(true);
    try {
      const [adminsRes, rolesRes, usersRes] = await Promise.all([
        supabase.from('admin_users').select('*').order('name'),
        supabase.from('admin_roles').select('*').order('name'),
        supabase.from('users').select('id, full_name, mobile, email, status').limit(200),
      ]);

      if (adminsRes.data) setAdminUsers(adminsRes.data);
      if (rolesRes.data) setRolesList(rolesRes.data);
      if (usersRes.data) setRegisteredUsers(usersRes.data);
    } catch (err) {
      console.error('Failed to load access control data:', err);
      showAlert('error', 'Error loading admin access data: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const showAlert = (type, text) => {
    setAlertMsg({ type, text });
    setTimeout(() => setAlertMsg({ type: '', text: '' }), 5000);
  };

  // Combine default roles with any custom database roles
  const allAvailableRoles = useMemo(() => {
    const map = new Map();
    // 1. Add system default roles
    DEFAULT_ROLES.forEach((r) => {
      map.set(r.name, {
        name: r.name,
        displayName: r.displayName,
        description: r.description,
        permissions: r.permissions,
        isSystem: true,
      });
    });
    // 2. Add or override from database admin_roles
    rolesList.forEach((r) => {
      const existing = map.get(r.name);
      map.set(r.name, {
        id: r.id,
        name: r.name,
        displayName: existing?.displayName || getRoleDisplayName(r.name),
        description: existing?.description || 'Custom administrative role',
        permissions: r.permissions || '*',
        isSystem: Boolean(existing?.isSystem),
      });
    });
    return Array.from(map.values());
  }, [rolesList]);

  // Filtered admin users
  const filteredAdmins = useMemo(() => {
    return adminUsers.filter((u) => {
      const q = search.toLowerCase();
      const matchSearch =
        !q ||
        u.name?.toLowerCase().includes(q) ||
        u.email?.toLowerCase().includes(q) ||
        String(u.mobile || '').includes(q) ||
        u.role?.toLowerCase().includes(q);

      const matchRole = roleFilter === 'all' || normalizeRole(u.role) === roleFilter;
      const matchStatus = statusFilter === 'all' || u.status === statusFilter;

      return matchSearch && matchRole && matchStatus;
    });
  }, [adminUsers, search, roleFilter, statusFilter]);

  // Candidate registered users for granting access
  const candidateUsers = useMemo(() => {
    const existingAdminEmails = new Set(
      adminUsers.map((a) => (a.email || '').toLowerCase().trim()).filter(Boolean)
    );
    const existingAdminMobiles = new Set(
      adminUsers.map((a) => String(a.mobile || '').slice(-10)).filter(Boolean)
    );

    const q = grantForm.searchUser.toLowerCase().trim();
    return registeredUsers
      .filter((u) => {
        const uEmail = (u.email || '').toLowerCase().trim();
        const uMobile = String(u.mobile || '').slice(-10);
        // Exclude users already in admin_users
        if (uEmail && existingAdminEmails.has(uEmail)) return false;
        if (uMobile && existingAdminMobiles.has(uMobile)) return false;
        if (!q) return true;
        return (
          u.full_name?.toLowerCase().includes(q) ||
          uEmail.includes(q) ||
          uMobile.includes(q)
        );
      })
      .slice(0, 15);
  }, [registeredUsers, adminUsers, grantForm.searchUser]);

  // ---------- Action: Create Brand New Admin ----------
  const handleCreateAdmin = async (e) => {
    e.preventDefault();
    if (!canManageAdmins) {
      showAlert('error', 'Security Violation: Only Super Admins can add new administrators.');
      return;
    }

    const { name, email, mobile, role, status } = createForm;
    const cleanEmail = (email || '').trim().toLowerCase();
    const cleanMobile = String(mobile || '').replace(/\D/g, '').slice(-10);

    if (!cleanEmail && !cleanMobile) {
      showAlert('error', 'Please provide either an email address or mobile number.');
      return;
    }

    try {
      const payload = {
        name: name.trim() || 'Admin User',
        email: cleanEmail || null,
        mobile: cleanMobile || null,
        role: normalizeRole(role),
        status: status || 'active',
      };

      const { data, error } = await supabase.from('admin_users').insert([payload]).select();
      if (error) throw error;

      showAlert('success', `Admin "${payload.name}" successfully created!`);
      setCreateModalOpen(false);
      setCreateForm({
        name: '',
        email: '',
        mobile: '',
        role: 'operations_manager',
        status: 'active',
      });
      loadData();
    } catch (err) {
      showAlert('error', `Failed to create admin: ${err.message}`);
    }
  };

  // ---------- Action: Grant Admin Access to Existing User ----------
  const handleGrantAccess = async (e) => {
    e.preventDefault();
    if (!canManageAdmins) {
      showAlert('error', 'Security Violation: Only Super Admins can grant administrative access.');
      return;
    }

    if (!grantForm.userId) {
      showAlert('error', 'Please select a registered customer/user to grant admin access.');
      return;
    }

    const user = registeredUsers.find((u) => u.id === grantForm.userId);
    if (!user) {
      showAlert('error', 'Selected user not found.');
      return;
    }

    try {
      const cleanEmail = (user.email || '').trim().toLowerCase();
      const cleanMobile = String(user.mobile || '').replace(/\D/g, '').slice(-10);

      const payload = {
        name: user.full_name || 'Admin',
        email: cleanEmail || null,
        mobile: cleanMobile || null,
        role: normalizeRole(grantForm.role),
        status: 'active',
      };

      const { error } = await supabase.from('admin_users').insert([payload]);
      if (error) throw error;

      showAlert(
        'success',
        `Admin access successfully granted to ${user.full_name} (${getRoleDisplayName(grantForm.role)})!`
      );
      setGrantModalOpen(false);
      setGrantForm({ userId: '', role: 'operations_manager', searchUser: '' });
      loadData();
    } catch (err) {
      showAlert('error', `Failed to grant admin access: ${err.message}`);
    }
  };

  // ---------- Action: Update Admin Details / Role / Status ----------
  const handleUpdateAdmin = async (e) => {
    e.preventDefault();
    if (!canManageAdmins) return;
    if (!editAdminModal) return;

    try {
      const { error } = await supabase
        .from('admin_users')
        .update({
          name: editAdminModal.name.trim(),
          email: editAdminModal.email?.trim().toLowerCase() || null,
          mobile: String(editAdminModal.mobile || '').replace(/\D/g, '').slice(-10) || null,
          role: normalizeRole(editAdminModal.role),
          status: editAdminModal.status,
        })
        .eq('id', editAdminModal.id);

      if (error) throw error;

      showAlert('success', `Admin profile for "${editAdminModal.name}" updated successfully.`);
      setEditAdminModal(null);
      loadData();
    } catch (err) {
      showAlert('error', `Failed to update admin: ${err.message}`);
    }
  };

  // ---------- Action: Quick Toggle Status (Active / Inactive) ----------
  const handleToggleStatus = async (admin) => {
    if (!canManageAdmins) return;
    const nextStatus = admin.status === 'active' ? 'inactive' : 'active';

    if (
      admin.id === currentAdmin?.id ||
      admin.email === currentAdmin?.email ||
      (admin.mobile && String(admin.mobile).slice(-10) === String(currentAdmin?.phone || currentAdmin?.mobile).slice(-10))
    ) {
      if (!confirm('Warning: You are modifying your own admin account. Continue?')) return;
    }

    try {
      const { error } = await supabase
        .from('admin_users')
        .update({ status: nextStatus })
        .eq('id', admin.id);

      if (error) throw error;
      showAlert('success', `Status for ${admin.name} updated to ${nextStatus}.`);
      loadData();
    } catch (err) {
      showAlert('error', `Could not update status: ${err.message}`);
    }
  };

  // ---------- Action: Revoke Admin Access (Delete) ----------
  const handleRevokeAdmin = async (admin) => {
    if (!canManageAdmins) return;

    // Safety checks
    if (
      admin.id === currentAdmin?.id ||
      admin.email === currentAdmin?.email ||
      (admin.mobile && String(admin.mobile).slice(-10) === String(currentAdmin?.phone || currentAdmin?.mobile).slice(-10))
    ) {
      alert('Security Protection: You cannot revoke or delete your own active admin session.');
      return;
    }

    const superAdminCount = adminUsers.filter(
      (a) => isSuperAdmin(a.role) && a.status === 'active'
    ).length;
    if (isSuperAdmin(admin.role) && superAdminCount <= 1) {
      alert(
        'Security Protection: Cannot delete the only remaining active Super Admin. Promote another Super Admin first.'
      );
      return;
    }

    if (
      !confirm(
        `Are you sure you want to completely REVOKE admin access for "${admin.name}" (${admin.email || admin.mobile})? They will immediately lose access to this control panel.`
      )
    ) {
      return;
    }

    try {
      const { error } = await supabase.from('admin_users').delete().eq('id', admin.id);
      if (error) throw error;
      showAlert('success', `Admin access permanently revoked for ${admin.name}.`);
      loadData();
    } catch (err) {
      showAlert('error', `Failed to revoke admin: ${err.message}`);
    }
  };

  // ---------- Action: Save Custom Role or Edit Permissions ----------
  const handleSaveRole = async (e) => {
    e.preventDefault();
    if (!canManageAdmins) return;

    const roleName = normalizeRole(editingRole ? editingRole.name : roleForm.name);
    if (!roleName) {
      showAlert('error', 'Please enter a role identifier.');
      return;
    }

    const perms = (editingRole ? editingRole.permissions : roleForm.permissions) || [];
    const permsString = Array.isArray(perms) ? perms.join(',') : String(perms);

    try {
      const payload = {
        name: roleName,
        permissions: permsString,
      };

      const { error } = await supabase
        .from('admin_roles')
        .upsert(payload, { onConflict: 'name' });
      if (error) throw error;

      showAlert('success', `Role "${roleName}" saved successfully with updated permissions.`);
      setCustomRoleModal(false);
      setEditingRole(null);
      setRoleForm({ name: '', displayName: '', description: '', permissions: [] });
      loadData();
    } catch (err) {
      showAlert('error', `Failed to save role: ${err.message}`);
    }
  };

  const currentRoleBadge = getRoleBadge(currentAdmin?.role || 'admin');

  return (
    <div style={{ maxWidth: 1200, margin: '0 auto' }}>
      <PageHead
        title="Admin Access & Roles Control"
        subtitle="Manage authorized staff, grant admin privileges to users, and enforce granular module access permissions."
        actions={
          canManageAdmins && (
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setGrantModalOpen(true)}
                style={{ display: 'flex', alignItems: 'center', gap: 6 }}
              >
                <span>👤</span> Grant Access to User
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => setCreateModalOpen(true)}
                style={{ display: 'flex', alignItems: 'center', gap: 6 }}
              >
                <span>+</span> Create New Admin
              </button>
            </div>
          )
        }
      />

      {/* Security Banner / Current Admin Badge */}
      <div
        style={{
          background: 'linear-gradient(135deg, #0d2416 0%, #153b24 100%)',
          borderRadius: 14,
          padding: '16px 22px',
          color: '#fff',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: 16,
          marginBottom: 20,
          boxShadow: '0 4px 16px rgba(12, 131, 31, 0.15)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: '50%',
              background: 'rgba(255,255,255,0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 22,
            }}
          >
            🔐
          </div>
          <div>
            <div style={{ fontSize: 16, fontWeight: 800 }}>Role-Based Access Control (RBAC) Active</div>
            <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.75)', marginTop: 2 }}>
              Only authenticated administrators with authorized clearance can access or modify system controls.
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.7)' }}>Your Clearance:</span>
          <span
            style={{
              background: currentRoleBadge.color,
              color: '#fff',
              padding: '6px 14px',
              borderRadius: 20,
              fontSize: 12,
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              boxShadow: '0 2px 6px rgba(0,0,0,0.2)',
            }}
          >
            <span>{currentRoleBadge.icon}</span>
            <span>{currentRoleBadge.label}</span>
          </span>
        </div>
      </div>

      {/* Alert Notice */}
      {alertMsg.text && (
        <div
          className={`sz-alert ${alertMsg.type === 'error' ? 'error' : 'success'}`}
          style={{ marginBottom: 16 }}
        >
          {alertMsg.text}
        </div>
      )}

      {/* Top Stats Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 20 }}>
        <div className="sz-stat blue" style={{ padding: '16px 20px' }}>
          <div className="label" style={{ fontSize: 11, textTransform: 'uppercase' }}>Total Admins</div>
          <div className="value" style={{ fontSize: 24, fontWeight: 900, marginTop: 4 }}>
            {adminUsers.length}
          </div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Registered staff profiles</div>
        </div>
        <div className="sz-stat green" style={{ padding: '16px 20px' }}>
          <div className="label" style={{ fontSize: 11, textTransform: 'uppercase' }}>Active Admins</div>
          <div className="value" style={{ fontSize: 24, fontWeight: 900, marginTop: 4, display: 'flex', alignItems: 'center', gap: 6 }}>
            {adminUsers.filter((a) => a.status === 'active').length} <span style={{ fontSize: 14 }}>🟢</span>
          </div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Authorized to log in</div>
        </div>
        <div className="sz-stat orange" style={{ padding: '16px 20px' }}>
          <div className="label" style={{ fontSize: 11, textTransform: 'uppercase' }}>Super Admins</div>
          <div className="value" style={{ fontSize: 24, fontWeight: 900, marginTop: 4 }}>
            {adminUsers.filter((a) => isSuperAdmin(a.role) || a.role === 'admin').length}
          </div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Full system privileges</div>
        </div>
        <div className="sz-stat green" style={{ padding: '16px 20px' }}>
          <div className="label" style={{ fontSize: 11, textTransform: 'uppercase' }}>Configured Roles</div>
          <div className="value" style={{ fontSize: 24, fontWeight: 900, marginTop: 4 }}>
            {allAvailableRoles.length}
          </div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Permission profiles</div>
        </div>
      </div>

      {/* Tabs Header */}
      <div
        style={{
          display: 'flex',
          gap: 12,
          borderBottom: '1px solid var(--border)',
          marginBottom: 20,
        }}
      >
        <button
          type="button"
          onClick={() => setActiveTab('admins')}
          style={{
            padding: '12px 18px',
            background: 'none',
            border: 'none',
            borderBottom: activeTab === 'admins' ? '3px solid var(--brand)' : '3px solid transparent',
            color: activeTab === 'admins' ? 'var(--brand)' : 'var(--text-muted)',
            fontWeight: activeTab === 'admins' ? 800 : 600,
            fontSize: 14,
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: 8,
          }}
        >
          <span>👥</span> Authorized Admin Users ({adminUsers.length})
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('roles')}
          style={{
            padding: '12px 18px',
            background: 'none',
            border: 'none',
            borderBottom: activeTab === 'roles' ? '3px solid var(--brand)' : '3px solid transparent',
            color: activeTab === 'roles' ? 'var(--brand)' : 'var(--text-muted)',
            fontWeight: activeTab === 'roles' ? 800 : 600,
            fontSize: 14,
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: 8,
          }}
        >
          <span>⚖️</span> Roles & Permissions Matrix ({allAvailableRoles.length})
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('security')}
          style={{
            padding: '12px 18px',
            background: 'none',
            border: 'none',
            borderBottom: activeTab === 'security' ? '3px solid var(--brand)' : '3px solid transparent',
            color: activeTab === 'security' ? 'var(--brand)' : 'var(--text-muted)',
            fontWeight: activeTab === 'security' ? 800 : 600,
            fontSize: 14,
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: 8,
          }}
        >
          <span>🛡️</span> Security & Access Policies
        </button>
      </div>

      {/* ========================================================================= */}
      {/* TAB 1: ADMIN USERS TABLE & CONTROLS                                       */}
      {/* ========================================================================= */}
      {activeTab === 'admins' && (
        <div className="sz-card" style={{ padding: 20 }}>
          {/* Search & Filters */}
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              gap: 12,
              flexWrap: 'wrap',
              marginBottom: 18,
            }}
          >
            <div style={{ flex: '1 1 300px', position: 'relative' }}>
              <input
                type="text"
                placeholder="Search by name, email, phone, or role…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{ paddingLeft: 34 }}
              />
              <span style={{ position: 'absolute', left: 12, top: 11, color: 'var(--text-muted)' }}>
                🔍
              </span>
            </div>

            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <select
                value={roleFilter}
                onChange={(e) => setRoleFilter(e.target.value)}
                style={{ width: 'auto', minWidth: 150 }}
              >
                <option value="all">All Roles</option>
                {allAvailableRoles.map((r) => (
                  <option key={r.name} value={r.name}>
                    {r.displayName}
                  </option>
                ))}
              </select>

              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                style={{ width: 'auto', minWidth: 130 }}
              >
                <option value="all">All Statuses</option>
                <option value="active">Active Only</option>
                <option value="inactive">Inactive Only</option>
              </select>

              {canManageAdmins && (
                <button
                  type="button"
                  className="btn btn-secondary btn-sm"
                  onClick={() => setGrantModalOpen(true)}
                  title="Make a registered user an admin"
                >
                  👤 Grant Access
                </button>
              )}
            </div>
          </div>

          {/* Table */}
          {loading ? (
            <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
              Loading administrator registry…
            </div>
          ) : filteredAdmins.length === 0 ? (
            <Empty text="No administrator profiles found matching criteria." />
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table className="sz-table" style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr>
                    <th style={{ textAlign: 'left' }}>Administrator</th>
                    <th style={{ textAlign: 'left' }}>Contact Info</th>
                    <th style={{ textAlign: 'left' }}>Assigned Role</th>
                    <th style={{ textAlign: 'left' }}>Access Status</th>
                    <th style={{ textAlign: 'right' }}>Security Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredAdmins.map((admin) => {
                    const roleBadge = getRoleBadge(admin.role);
                    const isActive = admin.status === 'active';
                    const isSelf =
                      admin.id === currentAdmin?.id ||
                      admin.email === currentAdmin?.email ||
                      (admin.mobile &&
                        String(admin.mobile).slice(-10) ===
                          String(currentAdmin?.phone || currentAdmin?.mobile).slice(-10));

                    return (
                      <tr key={admin.id} style={{ borderBottom: '1px solid var(--border)' }}>
                        {/* Admin Name & Avatar */}
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                            <div
                              style={{
                                width: 38,
                                height: 38,
                                borderRadius: '50%',
                                background: roleBadge.color,
                                color: '#fff',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                fontWeight: 800,
                                fontSize: 15,
                              }}
                            >
                              {(admin.name || 'A')[0].toUpperCase()}
                            </div>
                            <div>
                              <div style={{ fontWeight: 700, fontSize: 14 }}>
                                {admin.name || 'Admin'}
                                {isSelf && (
                                  <span
                                    style={{
                                      fontSize: 10,
                                      background: '#e0f2fe',
                                      color: '#0369a1',
                                      padding: '2px 6px',
                                      borderRadius: 4,
                                      marginLeft: 6,
                                      fontWeight: 800,
                                    }}
                                  >
                                    YOU
                                  </span>
                                )}
                              </div>
                              <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                                ID: {String(admin.id).slice(0, 8)}…
                              </div>
                            </div>
                          </div>
                        </td>

                        {/* Contact Info */}
                        <td>
                          <div style={{ fontSize: 13 }}>
                            {admin.email ? (
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                                <span>✉️</span> {admin.email}
                              </div>
                            ) : null}
                            {admin.mobile ? (
                              <div
                                style={{
                                  display: 'flex',
                                  alignItems: 'center',
                                  gap: 6,
                                  color: 'var(--text-muted)',
                                  marginTop: 2,
                                }}
                              >
                                <span>📱</span> +91 {String(admin.mobile).slice(-10)}
                              </div>
                            ) : null}
                            {!admin.email && !admin.mobile && (
                              <span style={{ color: 'var(--text-muted)' }}>—</span>
                            )}
                          </div>
                        </td>

                        {/* Role Badge */}
                        <td>
                          <span
                            style={{
                              background: `${roleBadge.color}15`,
                              color: roleBadge.color,
                              border: `1px solid ${roleBadge.color}35`,
                              padding: '4px 10px',
                              borderRadius: 16,
                              fontSize: 12,
                              fontWeight: 700,
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 6,
                            }}
                          >
                            <span>{roleBadge.icon}</span>
                            <span>{roleBadge.label}</span>
                          </span>
                        </td>

                        {/* Status */}
                        <td>
                          <button
                            type="button"
                            onClick={() => canManageAdmins && handleToggleStatus(admin)}
                            disabled={!canManageAdmins}
                            style={{
                              background: isActive ? '#dcfce7' : '#fee2e2',
                              color: isActive ? '#15803d' : '#b91c1c',
                              border: `1px solid ${isActive ? '#bbf7d0' : '#fecaca'}`,
                              padding: '4px 10px',
                              borderRadius: 14,
                              fontSize: 11,
                              fontWeight: 700,
                              cursor: canManageAdmins ? 'pointer' : 'default',
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 6,
                            }}
                            title={canManageAdmins ? 'Click to toggle status' : undefined}
                          >
                            <span>{isActive ? '🟢 Active' : '🔴 Inactive'}</span>
                          </button>
                        </td>

                        {/* Actions */}
                        <td style={{ textAlign: 'right' }}>
                          {canManageAdmins ? (
                            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
                              <button
                                type="button"
                                className="btn btn-secondary btn-sm"
                                onClick={() => setEditAdminModal(admin)}
                                title="Edit Role & Details"
                              >
                                ✏️ Edit
                              </button>
                              <button
                                type="button"
                                className="btn btn-danger btn-sm"
                                onClick={() => handleRevokeAdmin(admin)}
                                disabled={isSelf}
                                title={
                                  isSelf
                                    ? 'Cannot revoke your own access'
                                    : 'Revoke Admin Access'
                                }
                                style={{ opacity: isSelf ? 0.4 : 1 }}
                              >
                                🚫 Revoke
                              </button>
                            </div>
                          ) : (
                            <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>Read Only</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 2: ROLES & PERMISSIONS MATRIX                                         */}
      {/* ========================================================================= */}
      {activeTab === 'roles' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              flexWrap: 'wrap',
              gap: 12,
            }}
          >
            <div>
              <h3 style={{ margin: 0, fontSize: 18, fontWeight: 800 }}>Defined Access Roles</h3>
              <p style={{ margin: '4px 0 0', fontSize: 13, color: 'var(--text-muted)' }}>
                Each role grants specific navigation privileges and operational boundaries.
              </p>
            </div>

            {canManageAdmins && (
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => {
                  setRoleForm({
                    name: '',
                    displayName: '',
                    description: '',
                    permissions: ['dashboard', 'orders'],
                  });
                  setCustomRoleModal(true);
                }}
              >
                + Define Custom Role
              </button>
            )}
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(360px, 1fr))',
              gap: 16,
            }}
          >
            {allAvailableRoles.map((role) => {
              const badge = getRoleBadge(role.name);
              const permsList =
                role.permissions === '*'
                  ? ['* (Unrestricted Full Access)']
                  : (role.permissions || '').split(',').map((p) => p.trim()).filter(Boolean);

              const assignedCount = adminUsers.filter(
                (a) => normalizeRole(a.role) === normalizeRole(role.name)
              ).length;

              return (
                <div
                  key={role.name}
                  className="sz-card"
                  style={{
                    padding: 18,
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    borderTop: `4px solid ${badge.color}`,
                  }}
                >
                  <div>
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'flex-start',
                        marginBottom: 10,
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <span style={{ fontSize: 24 }}>{badge.icon}</span>
                        <div>
                          <h4 style={{ margin: 0, fontSize: 16, fontWeight: 800 }}>
                            {role.displayName || getRoleDisplayName(role.name)}
                          </h4>
                          <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                            slug: <code>{role.name}</code>
                          </span>
                        </div>
                      </div>

                      <span
                        style={{
                          fontSize: 11,
                          background: '#f1f5f9',
                          color: '#475569',
                          padding: '3px 8px',
                          borderRadius: 12,
                          fontWeight: 700,
                        }}
                      >
                        {assignedCount} user(s)
                      </span>
                    </div>

                    <p style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 14 }}>
                      {role.description || 'Standard access profile.'}
                    </p>

                    <div style={{ marginBottom: 16 }}>
                      <div
                        style={{
                          fontSize: 11,
                          fontWeight: 700,
                          textTransform: 'uppercase',
                          color: 'var(--text-muted)',
                          marginBottom: 8,
                        }}
                      >
                        Authorized Modules ({permsList.length}):
                      </div>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                        {permsList.map((perm) => (
                          <span
                            key={perm}
                            style={{
                              background: '#f8fafc',
                              border: '1px solid #e2e8f0',
                              color: '#334155',
                              padding: '2px 8px',
                              borderRadius: 6,
                              fontSize: 11,
                              fontWeight: 600,
                            }}
                          >
                            {perm === '* (Unrestricted Full Access)'
                              ? '⭐ ALL SYSTEM MODULES'
                              : perm}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>

                  {canManageAdmins && (
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'flex-end',
                        gap: 8,
                        borderTop: '1px solid var(--border)',
                        paddingTop: 12,
                      }}
                    >
                      <button
                        type="button"
                        className="btn btn-secondary btn-sm"
                        onClick={() => {
                          const currentPerms =
                            role.permissions === '*'
                              ? MODULES.map((m) => m.id)
                              : (role.permissions || '').split(',').map((p) => p.trim());

                          setEditingRole({
                            ...role,
                            permissions: currentPerms,
                          });
                        }}
                      >
                        ⚙️ Configure Permissions
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 3: SECURITY POLICIES & ENFORCEMENT                                    */}
      {/* ========================================================================= */}
      {activeTab === 'security' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="sz-card" style={{ padding: 22 }}>
            <h3 style={{ margin: '0 0 10px', fontSize: 18, fontWeight: 800 }}>
              🛡️ Security & Access Control Enforcement
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: 14, lineHeight: 1.6 }}>
              The Sabzee Admin Panel implements strict role-based access control. Only authorized administrators registered in the <code>admin_users</code> database table with <code>status = "active"</code> can log in or access internal operations.
            </p>

            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
                gap: 16,
                marginTop: 20,
              }}
            >
              <div
                style={{
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: 10,
                  padding: 16,
                }}
              >
                <div style={{ fontWeight: 800, fontSize: 14, color: '#0f172a', marginBottom: 6 }}>
                  🔒 Zero-Trust Login Gate
                </div>
                <div style={{ fontSize: 13, color: '#475569', lineHeight: 1.5 }}>
                  Public self-signups are prohibited. Any user attempting email or phone OTP login must be pre-authorized by an existing Super Admin.
                </div>
              </div>

              <div
                style={{
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: 10,
                  padding: 16,
                }}
              >
                <div style={{ fontWeight: 800, fontSize: 14, color: '#0f172a', marginBottom: 6 }}>
                  👑 Super Admin Hierarchy
                </div>
                <div style={{ fontSize: 13, color: '#475569', lineHeight: 1.5 }}>
                  Only accounts with <code>super_admin</code> or <code>admin</code> roles can create other admins, change permissions, or revoke access.
                </div>
              </div>

              <div
                style={{
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: 10,
                  padding: 16,
                }}
              >
                <div style={{ fontWeight: 800, fontSize: 14, color: '#0f172a', marginBottom: 6 }}>
                  🚫 Automatic Route Shielding
                </div>
                <div style={{ fontSize: 13, color: '#475569', lineHeight: 1.5 }}>
                  If a user attempts to bypass navigation or access unauthorized pages (e.g. settings or roles), the portal denies access with HTTP 403 shield.
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL 1: CREATE NEW ADMIN USER                                            */}
      {/* ========================================================================= */}
      {createModalOpen && (
        <Modal
          title="Create New Administrator Profile"
          onClose={() => setCreateModalOpen(false)}
        >
          <form onSubmit={handleCreateAdmin} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <p style={{ fontSize: 13, color: 'var(--text-muted)', margin: '0 0 4px' }}>
              Create an administrative profile. The user can then sign in via Email or Mobile OTP using their credentials.
            </p>

            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Full Name *
              </label>
              <input
                type="text"
                required
                placeholder="e.g. Rahul Sharma"
                value={createForm.name}
                onChange={(e) => setCreateForm({ ...createForm, name: e.target.value })}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Work Email Address
              </label>
              <input
                type="email"
                placeholder="e.g. rahul@sabzeewala.com"
                value={createForm.email}
                onChange={(e) => setCreateForm({ ...createForm, email: e.target.value })}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Mobile Number (10 digits for OTP login)
              </label>
              <input
                type="tel"
                placeholder="e.g. 9876543210"
                value={createForm.mobile}
                onChange={(e) => setCreateForm({ ...createForm, mobile: e.target.value })}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                  Assigned Role *
                </label>
                <select
                  value={createForm.role}
                  onChange={(e) => setCreateForm({ ...createForm, role: e.target.value })}
                >
                  {allAvailableRoles.map((r) => (
                    <option key={r.name} value={r.name}>
                      {r.displayName}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                  Initial Status
                </label>
                <select
                  value={createForm.status}
                  onChange={(e) => setCreateForm({ ...createForm, status: e.target.value })}
                >
                  <option value="active">Active (Can Log In)</option>
                  <option value="inactive">Inactive (Access Suspended)</option>
                </select>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 12 }}>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setCreateModalOpen(false)}
              >
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                Create Administrator
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* ========================================================================= */}
      {/* MODAL 2: GRANT ACCESS TO REGISTERED USER                                  */}
      {/* ========================================================================= */}
      {grantModalOpen && (
        <Modal
          title="Grant Admin Access to Existing User"
          wide
          onClose={() => setGrantModalOpen(false)}
        >
          <form onSubmit={handleGrantAccess} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <p style={{ fontSize: 13, color: 'var(--text-muted)', margin: 0 }}>
              Promote an existing customer or delivery partner to an administrative staff role.
            </p>

            {/* User Search Input */}
            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Search Registered Customer / User
              </label>
              <input
                type="text"
                placeholder="Search by user name, phone, or email…"
                value={grantForm.searchUser}
                onChange={(e) => setGrantForm({ ...grantForm, searchUser: e.target.value })}
              />
            </div>

            {/* Candidate User Selection List */}
            <div
              style={{
                maxHeight: 220,
                overflowY: 'auto',
                border: '1px solid var(--border)',
                borderRadius: 8,
                padding: 6,
              }}
            >
              {candidateUsers.length === 0 ? (
                <div style={{ padding: 16, textAlign: 'center', fontSize: 13, color: 'var(--text-muted)' }}>
                  No eligible non-admin users found matching query.
                </div>
              ) : (
                candidateUsers.map((u) => {
                  const isSelected = grantForm.userId === u.id;
                  return (
                    <div
                      key={u.id}
                      onClick={() => setGrantForm({ ...grantForm, userId: u.id })}
                      style={{
                        padding: '8px 12px',
                        borderRadius: 6,
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        cursor: 'pointer',
                        background: isSelected ? 'var(--brand-soft)' : 'transparent',
                        border: isSelected ? '1px solid var(--brand)' : '1px solid transparent',
                        marginBottom: 4,
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: 700, fontSize: 13 }}>
                          {u.full_name || 'Customer'}
                        </div>
                        <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                          📱 {u.mobile || '—'} {u.email ? ` · ✉️ ${u.email}` : ''}
                        </div>
                      </div>
                      <input
                        type="radio"
                        name="selected_user"
                        checked={isSelected}
                        onChange={() => setGrantForm({ ...grantForm, userId: u.id })}
                      />
                    </div>
                  );
                })
              )}
            </div>

            {/* Role to Assign */}
            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Role & Clearance Level to Grant *
              </label>
              <select
                value={grantForm.role}
                onChange={(e) => setGrantForm({ ...grantForm, role: e.target.value })}
              >
                {allAvailableRoles.map((r) => (
                  <option key={r.name} value={r.name}>
                    {r.displayName} — {r.description}
                  </option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 12 }}>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setGrantModalOpen(false)}
              >
                Cancel
              </button>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={!grantForm.userId}
              >
                Grant Admin Access
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* ========================================================================= */}
      {/* MODAL 3: EDIT ADMIN DETAILS & ROLE                                        */}
      {/* ========================================================================= */}
      {editAdminModal && (
        <Modal
          title={`Edit Admin: ${editAdminModal.name}`}
          onClose={() => setEditAdminModal(null)}
        >
          <form onSubmit={handleUpdateAdmin} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Full Name
              </label>
              <input
                type="text"
                required
                value={editAdminModal.name}
                onChange={(e) => setEditAdminModal({ ...editAdminModal, name: e.target.value })}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Email Address
              </label>
              <input
                type="email"
                value={editAdminModal.email || ''}
                onChange={(e) => setEditAdminModal({ ...editAdminModal, email: e.target.value })}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Mobile Number (10 digits)
              </label>
              <input
                type="tel"
                value={editAdminModal.mobile || ''}
                onChange={(e) => setEditAdminModal({ ...editAdminModal, mobile: e.target.value })}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                  Assigned Role
                </label>
                <select
                  value={editAdminModal.role}
                  onChange={(e) => setEditAdminModal({ ...editAdminModal, role: e.target.value })}
                >
                  {allAvailableRoles.map((r) => (
                    <option key={r.name} value={r.name}>
                      {r.displayName}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                  Status
                </label>
                <select
                  value={editAdminModal.status}
                  onChange={(e) => setEditAdminModal({ ...editAdminModal, status: e.target.value })}
                >
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </select>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 12 }}>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setEditAdminModal(null)}
              >
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                Save Changes
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* ========================================================================= */}
      {/* MODAL 4: CONFIGURE ROLE PERMISSIONS                                       */}
      {/* ========================================================================= */}
      {editingRole && (
        <Modal
          title={`Configure Permissions: ${getRoleDisplayName(editingRole.name)}`}
          wide
          onClose={() => setEditingRole(null)}
        >
          <form onSubmit={handleSaveRole} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <p style={{ fontSize: 13, color: 'var(--text-muted)', margin: 0 }}>
              Check the modules this role is authorized to view and manage in the Admin Panel.
            </p>

            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
                gap: 10,
                maxHeight: 340,
                overflowY: 'auto',
                padding: 4,
              }}
            >
              {MODULES.map((mod) => {
                const isChecked = editingRole.permissions.includes(mod.id);
                return (
                  <label
                    key={mod.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 8,
                      padding: '8px 12px',
                      background: isChecked ? 'var(--brand-soft)' : '#f8fafc',
                      border: `1px solid ${isChecked ? 'var(--brand)' : '#e2e8f0'}`,
                      borderRadius: 8,
                      fontSize: 13,
                      cursor: 'pointer',
                    }}
                  >
                    <input
                      type="checkbox"
                      checked={isChecked}
                      onChange={(e) => {
                        const next = e.target.checked
                          ? [...editingRole.permissions, mod.id]
                          : editingRole.permissions.filter((p) => p !== mod.id);
                        setEditingRole({ ...editingRole, permissions: next });
                      }}
                    />
                    <span>{mod.icon}</span>
                    <span style={{ fontWeight: isChecked ? 700 : 500 }}>{mod.label}</span>
                  </label>
                );
              })}
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 10 }}>
              <button
                type="button"
                className="btn btn-secondary btn-sm"
                onClick={() =>
                  setEditingRole({
                    ...editingRole,
                    permissions: MODULES.map((m) => m.id),
                  })
                }
              >
                Select All Modules
              </button>

              <div style={{ display: 'flex', gap: 10 }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setEditingRole(null)}
                >
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  Update Permissions
                </button>
              </div>
            </div>
          </form>
        </Modal>
      )}

      {/* ========================================================================= */}
      {/* MODAL 5: DEFINE CUSTOM ROLE                                               */}
      {/* ========================================================================= */}
      {customRoleModal && (
        <Modal
          title="Define New Custom Administrative Role"
          wide
          onClose={() => setCustomRoleModal(false)}
        >
          <form onSubmit={handleSaveRole} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Role Identifier (Slug) *
              </label>
              <input
                type="text"
                required
                placeholder="e.g. warehouse_supervisor"
                value={roleForm.name}
                onChange={(e) =>
                  setRoleForm({
                    ...roleForm,
                    name: e.target.value.toLowerCase().replace(/\s+/g, '_'),
                  })
                }
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 8 }}>
                Select Allowed Modules:
              </label>
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
                  gap: 10,
                  maxHeight: 280,
                  overflowY: 'auto',
                  padding: 4,
                }}
              >
                {MODULES.map((mod) => {
                  const isChecked = roleForm.permissions.includes(mod.id);
                  return (
                    <label
                      key={mod.id}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 8,
                        padding: '8px 12px',
                        background: isChecked ? 'var(--brand-soft)' : '#f8fafc',
                        border: `1px solid ${isChecked ? 'var(--brand)' : '#e2e8f0'}`,
                        borderRadius: 8,
                        fontSize: 13,
                        cursor: 'pointer',
                      }}
                    >
                      <input
                        type="checkbox"
                        checked={isChecked}
                        onChange={(e) => {
                          const next = e.target.checked
                            ? [...roleForm.permissions, mod.id]
                            : roleForm.permissions.filter((p) => p !== mod.id);
                          setRoleForm({ ...roleForm, permissions: next });
                        }}
                      />
                      <span>{mod.icon}</span>
                      <span style={{ fontWeight: isChecked ? 700 : 500 }}>{mod.label}</span>
                    </label>
                  );
                })}
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 12 }}>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setCustomRoleModal(false)}
              >
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                Save Custom Role
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
