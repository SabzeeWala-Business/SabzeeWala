import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'search_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_selector_sheet.dart';

class ProductListScreen extends StatefulWidget {
  final String categoryName;
  final String? initialSubCategoryName;

  const ProductListScreen({
    super.key,
    required this.categoryName,
    this.initialSubCategoryName,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _selectedSubCategory = "All";

  @override
  void initState() {
    super.initState();
    if (widget.initialSubCategoryName != null) {
      _selectedSubCategory = widget.initialSubCategoryName!;
    }
  }

  Widget _buildUnitDropdown(Product product, AppState appState) {
    if (!appState.hasProductVariants(product)) {
      return Text(
        product.unit,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textLight,
        ),
      );
    }

    final selectedUnit = appState.getProductSelectedUnit(product);
    final unitOptions = appState.getProductUnitOptions(product);

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 6),
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
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textLight),
          style: const TextStyle(fontSize: 11.5, color: AppColors.textDark, fontWeight: FontWeight.w600),
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
    final categoryProducts = appState.getProductsByCategory(
      widget.categoryName,
    );

    // Get dynamic sub-categories matching this category
    final matchingSubCats = appState.subCategories
        .where((s) => s.categoryId.toLowerCase() == widget.categoryName.toLowerCase().replaceAll(' ', '_'))
        .toList();
        
    final List<String> filterTags = [
      "All",
      ...matchingSubCats.map((s) => s.name),
      "Others",
    ];

    List<Product> displayedProducts = List.from(categoryProducts);
    if (_selectedSubCategory != "All") {
      if (_selectedSubCategory == "Others") {
        final subCatIds = matchingSubCats.map((s) => s.id).toSet();
        displayedProducts = categoryProducts.where((p) => !subCatIds.contains(p.subCategoryId)).toList();
      } else {
        final subCatObj = matchingSubCats.firstWhere(
          (s) => s.name.toLowerCase() == _selectedSubCategory.toLowerCase(),
          orElse: () => matchingSubCats.first,
        );
        displayedProducts = categoryProducts.where((p) => p.subCategoryId == subCatObj.id).toList();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CartScreen(showBackButton: true),
                    ),
                  );
                },
              ),
              if (appState.cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.discountText,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '${appState.cartCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Tags Bar
          Container(
            color: Colors.white,
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filterTags.length,
              itemBuilder: (context, index) {
                final tag = filterTags[index];
                final bool isSelected = _selectedSubCategory == tag;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSubCategory = tag;
                      });
                    },
                    selectedColor: AppColors.primary,
                    disabledColor: Colors.grey.shade100,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              },
            ),
          ),

          // Product List Grid/ListView
          Expanded(
            child: displayedProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No products in this category yet!',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayedProducts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = displayedProducts[index];
                      final selectedUnit = appState.getProductSelectedUnit(product);
                      final prices = appState.getProductPriceForUnit(product, selectedUnit);
                      final double activePrice = prices['price']!;
                      final double activeOriginalPrice = prices['originalPrice']!;
                      final int cartQty = appState.getProductQuantity(
                        product.id,
                        selectedUnit: selectedUnit,
                      );

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProductDetailScreen(product: product),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.01),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Product Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  child: ProductImage(
                                    imageUrl: product.imageUrl,
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Info Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildUnitDropdown(product, appState),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          cartQty > 1
                                              ? '₹${(activePrice * cartQty).toStringAsFixed(0)}'
                                              : '₹${activePrice.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: AppColors.textDark,
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
                                        if (activeOriginalPrice >
                                            activePrice) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            cartQty > 1
                                                ? '₹${(activeOriginalPrice * cartQty).toStringAsFixed(0)}'
                                                : '₹${activeOriginalPrice.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              fontSize: 12,
                                              color: AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Cart Add/Control widget
                              cartQty == 0
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
                                        side: const BorderSide(
                                          color: AppColors.primary,
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: const Text(
                                        'Add',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            onPressed: () => appState
                                                .removeFromCart(
                                                  product,
                                                  selectedUnit: selectedUnit,
                                                ),
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                          ),
                                          InkWell(
                                            onTap: () => showProductQuantitySelector(
                                              context,
                                              appState,
                                              product,
                                              cartQty,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6.0,
                                                vertical: 2.0,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '$cartQty',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const Icon(Icons.arrow_drop_down, color: Colors.white, size: 14),
                                                ],
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            onPressed: () =>
                                                appState.addToCart(
                                                  product,
                                                  selectedUnit: selectedUnit,
                                                  price: activePrice,
                                                  originalPrice: activeOriginalPrice,
                                                ),
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
