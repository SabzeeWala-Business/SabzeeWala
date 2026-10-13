import { supabase } from '../supabase';
import { STORAGE_BUCKET } from '../config';

/**
 * Upload an image file to the public Sabzee storage bucket.
 * Returns a public URL usable in products / categories / sub_categories.
 */
export async function uploadImage(file, folder = 'Products') {
  if (!file) throw new Error('No file selected');

  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
  const safeName = file.name
    .replace(/\.[^.]+$/, '')
    .replace(/[^a-zA-Z0-9_-]/g, '_')
    .slice(0, 40);
  const path = `${folder}/${Date.now()}_${safeName}.${ext}`;

  const { error } = await supabase.storage.from(STORAGE_BUCKET).upload(path, file, {
    cacheControl: '3600',
    upsert: true,
    contentType: file.type || `image/${ext}`,
  });

  if (error) throw error;

  const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path);
  return data.publicUrl;
}
