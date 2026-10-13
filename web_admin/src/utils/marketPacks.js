/**
 * India grocery / Blinkit–Zepto style pack sizes by product type.
 * Used for buying options (½ kg, 1 kg, dozen, etc.)
 */

export function getMarketPacks(productName = '', categoryName = '') {
  const n = String(productName).toLowerCase();
  const c = String(categoryName).toLowerCase();

  // Eggs
  if (n.includes('egg')) {
    return [
      { weight: 6, unit: 'pcs', label: '6 pcs' },
      { weight: 12, unit: 'pcs', label: '1 dozen' },
      { weight: 30, unit: 'pcs', label: '30 pcs tray' },
    ];
  }

  // Banana / plantain
  if (n.includes('banana') || n.includes('kela')) {
    return [
      { weight: 500, unit: 'g', label: '500 g' },
      { weight: 1, unit: 'kg', label: '1 kg' },
      { weight: 1, unit: 'dozen', label: '1 dozen' },
    ];
  }

  // Apple, orange, mango, pomegranate — fruit packs
  if (
    n.includes('apple') ||
    n.includes('orange') ||
    n.includes('mango') ||
    n.includes('pomegranate') ||
    n.includes('anar') ||
    n.includes('grapes') ||
    n.includes('guava') ||
    n.includes('papaya') ||
    n.includes('watermelon') ||
    n.includes('muskmelon')
  ) {
    return [
      { weight: 500, unit: 'g', label: '500 g' },
      { weight: 1, unit: 'kg', label: '1 kg' },
      { weight: 2, unit: 'kg', label: '2 kg' },
    ];
  }

  // Coconut / pineapple — pieces
  if (n.includes('coconut') || n.includes('pineapple') || n.includes('lemon') || n.includes('nimbu')) {
    return [
      { weight: 1, unit: 'pcs', label: '1 pc' },
      { weight: 2, unit: 'pcs', label: '2 pcs' },
      { weight: 4, unit: 'pcs', label: '4 pcs' },
    ];
  }

  // Leafy greens
  if (
    n.includes('spinach') ||
    n.includes('palak') ||
    n.includes('methi') ||
    n.includes('coriander') ||
    n.includes('dhania') ||
    n.includes('mint') ||
    n.includes('pudina') ||
    n.includes('lettuce') ||
    n.includes('cabbage') ||
    c.includes('leafy')
  ) {
    return [
      { weight: 100, unit: 'g', label: '100 g' },
      { weight: 250, unit: 'g', label: '250 g' },
      { weight: 500, unit: 'g', label: '500 g' },
    ];
  }

  // Potato, onion, tomato — staple veg
  if (
    n.includes('potato') ||
    n.includes('aloo') ||
    n.includes('onion') ||
    n.includes('pyaz') ||
    n.includes('tomato') ||
    n.includes('tamatar')
  ) {
    return [
      { weight: 500, unit: 'g', label: '500 g' },
      { weight: 1, unit: 'kg', label: '1 kg' },
      { weight: 2, unit: 'kg', label: '2 kg' },
      { weight: 5, unit: 'kg', label: '5 kg' },
    ];
  }

  // Ginger / garlic / chilli — small packs
  if (
    n.includes('ginger') ||
    n.includes('adrak') ||
    n.includes('garlic') ||
    n.includes('lehsun') ||
    n.includes('chilli') ||
    n.includes('mirch')
  ) {
    return [
      { weight: 100, unit: 'g', label: '100 g' },
      { weight: 250, unit: 'g', label: '250 g' },
      { weight: 500, unit: 'g', label: '500 g' },
    ];
  }

  // Milk / dairy liquids
  if (n.includes('milk') || n.includes('doodh') || (c.includes('dairy') && n.includes('toned'))) {
    return [
      { weight: 500, unit: 'ml', label: '500 ml' },
      { weight: 1, unit: 'liter', label: '1 liter' },
    ];
  }

  // Curd / paneer / ghee
  if (n.includes('curd') || n.includes('dahi') || n.includes('yogurt')) {
    return [
      { weight: 200, unit: 'g', label: '200 g' },
      { weight: 400, unit: 'g', label: '400 g' },
      { weight: 1, unit: 'kg', label: '1 kg' },
    ];
  }
  if (n.includes('paneer')) {
    return [
      { weight: 200, unit: 'g', label: '200 g' },
      { weight: 500, unit: 'g', label: '500 g' },
      { weight: 1, unit: 'kg', label: '1 kg' },
    ];
  }
  if (n.includes('ghee') || n.includes('butter')) {
    return [
      { weight: 100, unit: 'g', label: '100 g' },
      { weight: 200, unit: 'g', label: '200 g' },
      { weight: 500, unit: 'g', label: '500 g' },
      { weight: 1, unit: 'kg', label: '1 kg' },
    ];
  }

  // Bread / bakery pcs
  if (n.includes('bread') || n.includes('bun') || n.includes('pav') || c.includes('bakery')) {
    return [
      { weight: 1, unit: 'pcs', label: '1 pack' },
      { weight: 2, unit: 'pcs', label: '2 packs' },
    ];
  }

  // Atta / rice / dal / flour — grocery staples
  if (
    n.includes('atta') ||
    n.includes('flour') ||
    n.includes('rice') ||
    n.includes('chawal') ||
    n.includes('dal') ||
    n.includes('daal') ||
    n.includes('sugar') ||
    n.includes('cheeni') ||
    n.includes('salt') ||
    n.includes('namak') ||
    c.includes('grocery')
  ) {
    return [
      { weight: 500, unit: 'g', label: '500 g' },
      { weight: 1, unit: 'kg', label: '1 kg' },
      { weight: 2, unit: 'kg', label: '2 kg' },
      { weight: 5, unit: 'kg', label: '5 kg' },
    ];
  }

  // Oil
  if (n.includes('oil') || n.includes('tel')) {
    return [
      { weight: 500, unit: 'ml', label: '500 ml' },
      { weight: 1, unit: 'liter', label: '1 liter' },
      { weight: 5, unit: 'liter', label: '5 liter' },
    ];
  }

  // Beverages
  if (c.includes('beverag') || n.includes('juice') || n.includes('soda') || n.includes('water')) {
    return [
      { weight: 250, unit: 'ml', label: '250 ml' },
      { weight: 500, unit: 'ml', label: '500 ml' },
      { weight: 1, unit: 'liter', label: '1 liter' },
    ];
  }

  // Snacks / chips / namkeen — packs
  if (c.includes('snack') || c.includes('namkeen') || n.includes('chips') || n.includes('biscuit')) {
    return [
      { weight: 1, unit: 'pcs', label: '1 pack' },
      { weight: 2, unit: 'pcs', label: 'Combo 2' },
    ];
  }

  // Personal care
  /*if (c.includes('care') || c.includes('personal')) {
    return [{ weight: 1, unit: 'pcs', label: '1 pc' }];
  } */
  
  // Default vegetables / general produce (Blinkit style)
  if (c.includes('veg') || c.includes('fruit')) {
    return [
      { weight: 250, unit: 'g', label: '250 g' },
      { weight: 500, unit: 'g', label: '½ kg' },
      { weight: 1, unit: 'kg', label: '1 kg' },
    ];
  }

  // Generic fallback
  return [
    { weight: 250, unit: 'g', label: '250 g' },
    { weight: 500, unit: 'g', label: '500 g' },
    { weight: 1, unit: 'kg', label: '1 kg' },
  ];
}

export function packKey(weight, unit) {
  return `${weight}_${String(unit).toLowerCase()}`;
}
