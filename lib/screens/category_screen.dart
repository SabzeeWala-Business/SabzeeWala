import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'product_detail_screen.dart';
import 'search_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_selector_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  bool _isLoading = false;

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
    final categoriesList = appState.categories;
    final selectedCategoryIndex = appState.selectedCategoryIndex;
    final int safeIndex = (selectedCategoryIndex >= 0 && selectedCategoryIndex < categoriesList.length)
        ? selectedCategoryIndex
        : 0;
    final currentCategory = categoriesList.isNotEmpty
        ? categoriesList[safeIndex]
        : CategoryItem(id: 'vegetables', name: 'Vegetables');
    final currentCategoryName = currentCategory.name;

    // Get matching subcategories
    final matchingSubCats = appState.subCategories
        .where((s) => s.categoryId.toLowerCase() == currentCategory.id.toLowerCase() || s.categoryId.toLowerCase() == currentCategoryName.toLowerCase().replaceAll(' ', '_'))
        .toList();

    final List<String> dropdownOptions = [
      "All",
      ...matchingSubCats.map((s) => s.name),
      "Others",
    ];

    final selectedSubName = appState.selectedSubCategoryName;

    // Filter products dynamically
    List<Product> displayedProducts = appState.getProductsByCategory(
      currentCategoryName,
    );
    if (appState.isOrganicFilterOnly) {
      displayedProducts = displayedProducts
          .where((p) => p.isOrganic)
          .toList();
    }

    if (selectedSubName != "All") {
      if (selectedSubName == "Others") {
        final subCatIds = matchingSubCats.map((s) => s.id).toSet();
        displayedProducts = displayedProducts.where((p) => !subCatIds.contains(p.subCategoryId)).toList();
      } else {
        final subCatObj = matchingSubCats.firstWhere(
          (s) => s.name.toLowerCase() == selectedSubName.toLowerCase(),
          orElse: () => matchingSubCats.first,
        );
        displayedProducts = displayedProducts.where((p) => p.subCategoryId == subCatObj.id).toList();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Provider.of<AppState>(context, listen: false).setNavIndex(0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Categories',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 18),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Provider.of<AppState>(context, listen: false).setNavIndex(0);
              }
            },
          ),
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
        ],
      ),
      body: Row(
        children: [
          // 1. LEFT SIDEBAR NAVIGATION PANE
          Container(
            width: 78,
            color: const Color(0xFFF4F6F4),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: categoriesList.length,
              itemBuilder: (context, index) {
                final category = categoriesList[index];
                final bool isSelected = safeIndex == index;
                final String imgUrl = category.imageUrl.isNotEmpty
                    ? category.imageUrl
                    : 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Veggies.webp';

                return GestureDetector(
                  onTap: () {
                    appState.setSelectedCategoryIndex(index);
                    setState(() {
                      _isLoading = true;
                    });
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    });
                  },
                  child: Container(
                    color: isSelected ? Colors.white : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12), // Expanded vertical padding to increase item height spacing
                    child: Stack(
                      children: [
                        // Left boundary vertical bar active line indicator
                        if (isSelected)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 3,
                            child: Container(color: AppColors.primary),
                          ),
                        // Content
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 36, // Increased height image container
                                width: 36, // Increased width image container
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: () {
                                    final String resolved = ProductImage.getLocalAssetOrUrl(imgUrl);
                                    if (resolved.startsWith('assets/')) {
                                      return Image.asset(
                                        resolved,
                                        fit: BoxFit.cover,
                                        cacheWidth: 60,
                                        cacheHeight: 60,
                                      );
                                    } else {
                                      return CachedNetworkImage(
                                        imageUrl: resolved,
                                        fit: BoxFit.cover,
                                        maxWidthDiskCache: 60,
                                        maxHeightDiskCache: 60,
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: AppColors.primary.withOpacity(0.1),
                                              child: const Icon(
                                                Icons.eco_outlined,
                                                color: AppColors.primary,
                                                size: 18,
                                              ),
                                            ),
                                      );
                                    }
                                  }(),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                category.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5, // Increased font size for better readability and width matching
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.textDark
                                      : AppColors.textLight,
                                ),
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

          // 2. RIGHT PRODUCTS GRID PANE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filters Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Organic toggle chip
                        ChoiceChip(
                          label: const Text('Organic'),
                          selected: appState.isOrganicFilterOnly,
                          onSelected: (selected) {
                            appState.setIsOrganicFilterOnly(selected);
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: appState.isOrganicFilterOnly
                                ? Colors.white
                                : AppColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Subcategory selection dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: dropdownOptions.contains(selectedSubName) ? selectedSubName : "All",
                              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textDark),
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  appState.setSelectedSubCategoryName(newValue);
                                }
                              },
                              items: dropdownOptions.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Grid View of Products
                Expanded(
                  child: _isLoading
                      ? _buildShimmerGrid()
                      : displayedProducts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No products in $currentCategoryName matching options.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.only(
                            left: 8,
                            right: 8,
                            bottom: 96, // Ample clearance above the floating dock
                          ),
                          itemCount: displayedProducts.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio:
                                    0.49, // Responsive card aspect ratio for compact mobile screens
                              ),
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
                            
                            int discountPercent = 0;
                            if (activeOriginalPrice > 0 && activePrice < activeOriginalPrice) {
                              discountPercent = (((activeOriginalPrice - activePrice) / activeOriginalPrice) * 100).round();
                            }

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
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE8F5E9), // Premium light green border
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04), // Softer, premium shadow
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Product Image & Badges with soft background container
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF9FBF9),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: ProductImage(
                                                  imageUrl: product.imageUrl,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Discount badge
                                          if (activeOriginalPrice > activePrice)
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade800,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '$discountPercent% OFF',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          // Top-Right Favorite Heart Icon
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () {
                                                appState.toggleFavorite(
                                                  product.id,
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  5,
                                                ),
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
                                                child: Icon(
                                                  appState.isFavorite(
                                                        product.id,
                                                      )
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color:
                                                      appState.isFavorite(
                                                        product.id,
                                                      )
                                                      ? Colors.red
                                                      : Colors.grey.shade400,
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Organic badge
                                          if (product.isOrganic)
                                            Positioned(
                                              bottom: 8,
                                              right: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: AppColors.primary
                                                        .withOpacity(0.2),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Organic',
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (!appState.isProductInStock(product.id))
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.55),
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(16),
                                                    topRight: Radius.circular(16),
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.8),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'OUT OF STOCK',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 9,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Info details
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                          const SizedBox(height: 2),
                                          _buildUnitDropdown(product, appState),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${product.rating}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Row(
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
                                                ] else if (activeOriginalPrice >
                                                    activePrice) ...[
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '₹${activeOriginalPrice.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      decoration: TextDecoration
                                                          .lineThrough,
                                                      fontSize: 11,
                                                      color: AppColors.textLight,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // ADD button
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 10,
                                        right: 10,
                                        bottom: 10,
                                      ),
                                      child: !appState.isProductInStock(product.id)
                                          ? Container(
                                              width: double.infinity,
                                              height: 36,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.grey.shade300, width: 0.8),
                                              ),
                                              child: Text(
                                                'SOLD OUT',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade500,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            )
                                          : cartQty == 0
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
                                                backgroundColor:
                                                    AppColors.primary,
                                                foregroundColor: Colors.white,
                                                elevation: 2,
                                                shadowColor: AppColors.primary
                                                    .withOpacity(0.3),
                                                minimumSize:
                                                    const Size.fromHeight(36),
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text(
                                                'ADD',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primary
                                                        .withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                               child: FittedBox(
                                                 fit: BoxFit.scaleDown,
                                                 child: Row(
                                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                   children: [
                                                     InkWell(
                                                       onTap: () => appState.removeFromCart(
                                                         product,
                                                         selectedUnit: selectedUnit,
                                                       ),
                                                       borderRadius: const BorderRadius.only(
                                                         topLeft: Radius.circular(10),
                                                         bottomLeft: Radius.circular(10),
                                                       ),
                                                       child: const Padding(
                                                         padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                                         child: Icon(Icons.remove, color: Colors.white, size: 12),
                                                       ),
                                                     ),
                                                     InkWell(
                                                       onTap: () => showProductQuantitySelector(
                                                         context,
                                                         appState,
                                                         product,
                                                         cartQty,
                                                       ),
                                                       child: Padding(
                                                         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                         child: Row(
                                                           mainAxisSize: MainAxisSize.min,
                                                           children: [
                                                             Text(
                                                               '',
                                                               style: const TextStyle(
                                                                 color: Colors.white,
                                                                 fontWeight: FontWeight.bold,
                                                                 fontSize: 12,
                                                               ),
                                                             ),
                                                             const Icon(Icons.arrow_drop_down, color: Colors.white, size: 14),
                                                           ],
                                                         ),
                                                       ),
                                                     ),
                                                     InkWell(
                                                       onTap: () => appState.addToCart(
                                                         product,
                                                         selectedUnit: selectedUnit,
                                                         price: activePrice,
                                                         originalPrice: activeOriginalPrice,
                                                       ),
                                                       borderRadius: const BorderRadius.only(
                                                         topRight: Radius.circular(10),
                                                         bottomRight: Radius.circular(10),
                                                       ),
                                                       child: const Padding(
                                                         padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                                         child: Icon(Icons.add, color: Colors.white, size: 12),
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                               ),
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
          ),
        ],
      ),
    ),
  );
}

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.50,
      ),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 80,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 40,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 14,
                        width: 50,
                        color: Colors.grey.shade200,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 32,
                  margin: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
