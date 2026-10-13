import React, { useRef, useState } from 'react';
import { uploadImage } from '../utils/imageUpload';

/**
 * Compact image picker: upload to Supabase Storage or paste a URL.
 */
export default function ImageUploader({ value, onChange, folder = 'Products', label = 'Image' }) {
  const inputRef = useRef(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');

  const handleFile = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setError('');
    try {
      const url = await uploadImage(file, folder);
      onChange(url);
    } catch (err) {
      setError(err.message || 'Upload failed. You can still paste an image URL.');
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = '';
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <label style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
        {label}
      </label>
      {value ? (
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <img
            src={value}
            alt="preview"
            style={{
              width: 56,
              height: 56,
              objectFit: 'cover',
              borderRadius: 8,
              border: '1px solid var(--border-color)',
              background: '#f5f5f5',
            }}
          />
          <button
            type="button"
            onClick={() => onChange('')}
            style={{
              background: '#ffebee',
              color: 'var(--danger-color)',
              padding: '6px 10px',
              borderRadius: 6,
              fontSize: 12,
            }}
          >
            Remove
          </button>
        </div>
      ) : null}
      <input
        type="url"
        placeholder="Paste image URL or upload below"
        value={value || ''}
        onChange={(e) => onChange(e.target.value)}
      />
      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
        <input
          ref={inputRef}
          type="file"
          accept="image/*"
          onChange={handleFile}
          disabled={uploading}
          style={{ fontSize: 12, padding: 6 }}
        />
        {uploading && <span style={{ fontSize: 12, color: 'var(--primary)' }}>Uploading…</span>}
      </div>
      {error && <div style={{ fontSize: 12, color: 'var(--danger-color)' }}>{error}</div>}
    </div>
  );
}
