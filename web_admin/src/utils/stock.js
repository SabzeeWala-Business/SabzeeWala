import { supabase } from '../supabase';

/**
 * Production stock helpers — Supabase only. No mock / localStorage inventory.
 */

export function getVariantStock(variant) {
  if (variant?.stock_total != null && variant.stock_total !== '') {
    return Number(variant.stock_total);
  }
  if (variant?.total_stock != null && variant.total_stock !== '') {
    return Number(variant.total_stock);
  }
  return null; // unknown — column not populated
}

export async function setVariantStock(variantId, productId, nextStock) {
  const qty = Math.max(0, Number(nextStock) || 0);
  const { error } = await supabase
    .from('product_variants')
    .update({ stock_total: qty })
    .eq('id', variantId);

  if (error) {
    throw new Error(
      error.message.includes('stock_total') || error.code === 'PGRST204'
        ? 'Stock column is not available on product_variants. Add stock_total in Supabase to manage inventory.'
        : error.message
    );
  }

  if (productId) {
    await supabase
      .from('products')
      .update({ status: qty <= 0 ? 'inactive' : 'active' })
      .eq('id', productId);
  }

  return qty;
}

/**
 * On order delivered — decrement stock_total for each line item (DB only).
 */
export async function deductStockForDeliveredOrder(order) {
  const items = order?.order_items || [];
  if (!items.length) return { ok: true, deducted: [], skipped: true };

  const deducted = [];
  const errors = [];

  for (const item of items) {
    const variantId = item.variant_id;
    if (!variantId) continue;
    const qty = Number(item.quantity || 0);
    if (qty <= 0) continue;

    const { data: variant, error: fetchErr } = await supabase
      .from('product_variants')
      .select('id, product_id, stock_total, total_stock')
      .eq('id', variantId)
      .maybeSingle();

    if (fetchErr || !variant) {
      errors.push(variantId);
      continue;
    }

    const current = getVariantStock(variant);
    if (current == null) {
      errors.push(`${variantId}:no_stock_field`);
      continue;
    }

    const next = Math.max(0, current - qty);
    try {
      await setVariantStock(variant.id, variant.product_id, next);
      deducted.push({
        variantId: variant.id,
        productId: variant.product_id,
        sold: qty,
        remaining: next,
      });
    } catch (e) {
      errors.push(e.message);
    }
  }

  return { ok: errors.length === 0, deducted, errors };
}
