import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'cart_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_selector_sheet.dart';
import '../services/supabase_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    SupabaseService().updateUserActivity('details', searchQuery: widget.product.name);
  }

  Widget _buildUnitDropdown(Product product, AppState appState) {
    if (!appState.hasProductVariants(product)) {
      return Text(
        product.unit,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textLight,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final activeUnit = appState.getProductSelectedUnit(product);
    final unitOptions = appState.getProductUnitOptions(product);

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: unitOptions.contains(activeUnit) ? activeUnit : (unitOptions.isNotEmpty ? unitOptions.first : activeUnit),
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textLight),
          style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
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
    final product = appState.findProductById(widget.product.id) ?? widget.product;
    final activeUnit = appState.getProductSelectedUnit(product);
    final prices = appState.getProductPriceForUnit(product, activeUnit);
    final double activePrice = prices['price']!;
    final double activeOriginalPrice = prices['originalPrice']!;
    
    final int cartQty = appState.getProductQuantity(
      product.id,
      selectedUnit: activeUnit,
    );

    int discountPercent = 0;
    if (activeOriginalPrice > 0 && activePrice < activeOriginalPrice) {
      discountPercent = (((activeOriginalPrice - activePrice) / activeOriginalPrice) * 100).round();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textDark),
            onPressed: () => _showShareSheet(context, product, activePrice, activeUnit),
          ),
          IconButton(
            icon: Icon(
              appState.isFavorite(product.id)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: appState.isFavorite(product.id)
                  ? Colors.red
                  : AppColors.textDark,
            ),
            onPressed: () => appState.toggleFavorite(product.id),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Product Image Section
                    Container(
                      height: 260,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Hero(
                          tag: 'product_image_${product.id}',
                          child: ProductImage(
                            imageUrl: product.imageUrl,
                            fit: BoxFit.contain,
                            width: 260,
                          ),
                        ),
                      ),
                    ),

                    // Product Information Sheet
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title and Unit
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _buildUnitDropdown(product, appState),
                                  ],
                                ),
                              ),
                              // Rating badge
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.rating}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    ' (${product.ratingCount})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Pricing and Discount Tag
                          Row(
                            children: [
                              Text(
                                cartQty > 1
                                    ? '₹${(activePrice * cartQty).toStringAsFixed(0)}'
                                    : '₹${activePrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (cartQty > 1) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(${cartQty} x ₹${activePrice.toStringAsFixed(0)})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                              if (activeOriginalPrice > activePrice) ...[
                                const SizedBox(width: 10),
                                Text(
                                  cartQty > 1
                                      ? '₹${(activeOriginalPrice * cartQty).toStringAsFixed(0)}'
                                      : '₹${activeOriginalPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    decoration: TextDecoration.lineThrough,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.discountBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$discountPercent% OFF',
                                    style: const TextStyle(
                                      color: AppColors.discountText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Description
                          const Text(
                            'Product Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Interaction Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (appState.isProductInStock(product.id)) ...[
                    // Quantity Controller
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove,
                              color: AppColors.primary,
                            ),
                            onPressed: cartQty > 0
                                ? () => appState.removeFromCart(
                                      product,
                                      selectedUnit: activeUnit,
                                    )
                                : null,
                          ),
                          InkWell(
                            onTap: () => showProductQuantitySelector(
                              context,
                              appState,
                              product,
                              cartQty,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$cartQty',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down, color: AppColors.textDark, size: 20),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.primary,
                            ),
                            onPressed: () => appState.addToCart(
                              product,
                              selectedUnit: activeUnit,
                              price: activePrice,
                              originalPrice: activeOriginalPrice,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],

                  // Add to Cart / Go to checkout button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !appState.isProductInStock(product.id)
                          ? null
                          : () {
                              if (cartQty == 0) {
                                appState.addToCart(
                                  product,
                                  selectedUnit: activeUnit,
                                  price: activePrice,
                                  originalPrice: activeOriginalPrice,
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CartScreen(showBackButton: true),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !appState.isProductInStock(product.id)
                            ? Colors.grey.shade300
                            : AppColors.primary,
                        foregroundColor: !appState.isProductInStock(product.id)
                            ? Colors.grey.shade500
                            : Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        !appState.isProductInStock(product.id)
                            ? 'OUT OF STOCK'
                            : (cartQty == 0
                                ? 'Add to Cart • ₹${activePrice.toStringAsFixed(0)}'
                                : 'Go to Cart • ₹${(activePrice * cartQty).toStringAsFixed(0)}'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareSheet(BuildContext context, Product product, double price, String unit) {
    final String shareText = "Check out fresh ${product.name} ($unit) on SabzeeWala for only ₹${price.toStringAsFixed(0)}! Order now: https://sabzeewala.com/p/${product.id}";
    final String encodedText = Uri.encodeComponent(shareText);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Share Product",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${product.name} - ₹${price.toStringAsFixed(0)} ($unit)",
                style: const TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text("Share on WhatsApp"),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final Uri waUrl = Uri.parse("https://wa.me/?text=$encodedText");
                  try {
                    await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    final Uri waWeb = Uri.parse("https://api.whatsapp.com/send?text=$encodedText");
                    try {
                      await launchUrl(waWeb, mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Could not launch WhatsApp.")),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.message_outlined, size: 18),
                label: const Text("Share via SMS"),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final Uri smsUrl = Uri.parse("sms:?body=$encodedText");
                  try {
                    await launchUrl(smsUrl);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Could not launch SMS app.")),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                label: const Text("Copy Product Details", style: TextStyle(color: AppColors.primary)),
                onPressed: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: shareText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Product details copied to clipboard!"),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
