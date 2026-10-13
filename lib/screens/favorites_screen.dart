import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'product_detail_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_selector_sheet.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Widget _buildUnitDropdown(Product product, AppState appState) {
    if (!appState.hasProductVariants(product)) {
      return Text(
        product.unit,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textLight,
        ),
      );
    }

    final selectedUnit = appState.getProductSelectedUnit(product);
    final unitOptions = appState.getProductUnitOptions(product);

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: unitOptions.contains(selectedUnit) ? selectedUnit : (unitOptions.isNotEmpty ? unitOptions.first : selectedUnit),
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textLight),
          style: const TextStyle(fontSize: 10.5, color: AppColors.textDark, fontWeight: FontWeight.w600),
          onChanged: (String? newValue) {
            if (newValue != null) {
              appState.setProductSelectedUnit(product.id, newValue);
            }
          },
          items: unitOptions.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final favProducts = appState.favoriteProducts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Wishlist',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: favProducts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_outline, color: Colors.red.shade400, size: 64),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Your Wishlist is Empty!",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Tap the heart on items to add them here.",
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.60,
              ),
              itemBuilder: (context, index) {
                final product = favProducts[index];
                final selectedUnit = appState.getProductSelectedUnit(product);
                final prices = appState.getProductPriceForUnit(product, selectedUnit);
                final activePrice = prices['price']!;
                final activeOriginalPrice = prices['originalPrice']!;
                final int cartQty = appState.getProductQuantity(product.id, selectedUnit: selectedUnit);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image Stack
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FBF9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ProductImage(
                                      imageUrl: product.imageUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              // Heart removal icon
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    appState.toggleFavorite(product.id);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.favorite,
                                      color: Colors.red,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Information
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildUnitDropdown(product, appState),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    cartQty > 1
                                        ? '₹${(activePrice * cartQty).toStringAsFixed(0)}'
                                        : '₹${activePrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  if (cartQty > 1) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${cartQty}x₹${activePrice.toStringAsFixed(0)})',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textLight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (activeOriginalPrice > activePrice) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      cartQty > 1
                                          ? '₹${(activeOriginalPrice * cartQty).toStringAsFixed(0)}'
                                          : '₹${activeOriginalPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Add to Cart
                        Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                          child: cartQty == 0
                              ? ElevatedButton(
                                  onPressed: () {
                                    appState.addToCart(
                                      product,
                                      selectedUnit: selectedUnit,
                                      price: activePrice,
                                      originalPrice: activeOriginalPrice,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.primary,
                                    elevation: 0,
                                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: const Text("ADD", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                )
                              : Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                                        onPressed: () => appState.removeFromCart(product, selectedUnit: selectedUnit),
                                      ),
                                      InkWell(
                                        onTap: () => showProductQuantitySelector(
                                          context,
                                          appState,
                                          product,
                                          cartQty,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$cartQty',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 14),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                        onPressed: () => appState.addToCart(
                                          product,
                                          selectedUnit: selectedUnit,
                                          price: activePrice,
                                          originalPrice: activeOriginalPrice,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
