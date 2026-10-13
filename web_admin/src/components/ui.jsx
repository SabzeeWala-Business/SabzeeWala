import React from 'react';

export function Modal({ open = true, title, onClose, children, wide }) {
  if (open === false) return null;
  return (
    <div className="sz-modal-backdrop" onClick={onClose}>
      <div
        className="sz-modal"
        style={wide ? { width: 'min(720px, 100%)' } : undefined}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
          <h3 style={{ margin: 0 }}>{title}</h3>
          <button type="button" className="btn btn-ghost btn-sm" onClick={onClose}>
            Close
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function Empty({ text = 'No data yet' }) {
  return <div className="sz-empty">{text}</div>;
}

export function MissingTable({ name }) {
  return (
    <div className="sz-alert info">
      Table <strong>{name}</strong> is not available in your Supabase project yet. Other modules using
      existing tables still work. Add this table in Supabase when you are ready — the UI is ready.
    </div>
  );
}

export function PageHead({ title, subtitle, actions }) {
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        gap: 12,
        flexWrap: 'wrap',
        alignItems: 'flex-start',
        marginBottom: 18,
      }}
    >
      <div>
        <h2
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 22,
            fontWeight: 800,
            letterSpacing: '-0.03em',
          }}
        >
          {title}
        </h2>
        {subtitle && (
          <p style={{ color: 'var(--text-muted)', fontSize: 13, marginTop: 4 }}>{subtitle}</p>
        )}
      </div>
      {actions && <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>{actions}</div>}
    </div>
  );
}

export function Stat({ label, value, tone = 'green' }) {
  return (
    <div className={`sz-stat ${tone}`}>
      <div className="label">{label}</div>
      <div className="value">{value}</div>
    </div>
  );
}
