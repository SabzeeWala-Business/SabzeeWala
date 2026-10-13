import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'product_detail_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_selector_sheet.dart';
import '../services/supabase_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  String _searchQuery = "";
  List<String> _recentSearches = [];

  void _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  void _saveRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> current = prefs.getStringList('recent_searches') ?? [];
    current.remove(q); // remove duplicate
    current.insert(0, q); // add to top
    if (current.length > 5) {
      current = current.sublist(0, 5); // limit to 5
    }
    await prefs.setStringList('recent_searches', current);
    setState(() {
      _recentSearches = current;
    });
  }

  void _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() {
      _recentSearches = [];
    });
  }

  bool _isMatch(String productName, String productCategory, String query) {
    if (query.trim().isEmpty) return false;
    final nameLower = productName.toLowerCase();
    final catLower = productCategory.toLowerCase();
    
    // Split query into individual keywords
    final keywords = query.toLowerCase().trim().split(RegExp(r'\s+'));
    
    // Every keyword in the query must match the product name or category
    return keywords.every((kw) {
      if (nameLower.contains(kw) || catLower.contains(kw)) return true;
      
      // Singular/plural normalization of keyword
      String rootKw = kw;
      if (kw.endsWith("es") && kw.length > 2) {
        rootKw = kw.substring(0, kw.length - 2);
      } else if (kw.endsWith("s") && kw.length > 1) {
        rootKw = kw.substring(0, kw.length - 1);
      }
      
      if (nameLower.contains(rootKw) || catLower.contains(rootKw)) return true;
      
      // Singular/plural normalization of product name words
      final nameWords = nameLower.split(RegExp(r'\s+'));
      for (final nw in nameWords) {
        String rootNw = nw;
        if (nw.endsWith("es") && nw.length > 2) {
          rootNw = nw.substring(0, nw.length - 2);
        } else if (nw.endsWith("s") && nw.length > 1) {
          rootNw = nw.substring(0, nw.length - 1);
        }
        if (kw.contains(rootNw) || rootNw.contains(kw)) return true;
      }
      
      return false;
    });
  }

  void _handleSearchTap(String query, List<Product> allProducts) {
    _saveRecentSearch(query);

    Product? exactMatch;
    for (final p in allProducts) {
      if (_isMatch(p.name, p.category, query)) {
        exactMatch = p;
        break;
      }
    }

    if (exactMatch == null) {
      for (final p in allProducts) {
        if (p.name.toLowerCase().contains(query.toLowerCase()) || query.toLowerCase().contains(p.name.toLowerCase())) {
          exactMatch = p;
          break;
        }
      }
    }

    if (exactMatch != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailScreen(product: exactMatch!),
        ),
      );
    } else {
      setState(() {
        _searchQuery = query;
        _queryController.text = query;
      });
      _updateSearchActivity(query);
    }
  }

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
  void initState() {
    super.initState();
    _updateSearchActivity(_searchQuery);
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _updateSearchActivity(String query) {
    SupabaseService().updateUserActivity(
      query.isEmpty ? 'browsing' : 'searching',
      searchQuery: query.isEmpty ? null : query,
    );
  }


  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final allProducts = appState.products;

    final filteredProducts = allProducts.where((product) {
      if (_searchQuery.trim().isEmpty) return true;
      final nameLower = product.name.toLowerCase();
      final catLower = product.category.toLowerCase();
      
      // Split query into individual keywords
      final keywords = _searchQuery.toLowerCase().trim().split(RegExp(r'\s+'));
      
      // Every keyword in the search query must match the product name or category
      return keywords.every((kw) {
        if (nameLower.contains(kw) || catLower.contains(kw)) return true;
        
        // Singular/plural normalization of keyword
        String rootKw = kw;
        if (kw.endsWith("es") && kw.length > 2) {
          rootKw = kw.substring(0, kw.length - 2);
        } else if (kw.endsWith("s") && kw.length > 1) {
          rootKw = kw.substring(0, kw.length - 1);
        }
        
        if (nameLower.contains(rootKw) || catLower.contains(rootKw)) return true;
        
        // Singular/plural normalization of product name words
        final nameWords = nameLower.split(RegExp(r'\s+'));
        for (final nw in nameWords) {
          String rootNw = nw;
          if (nw.endsWith("es") && nw.length > 2) {
            rootNw = nw.substring(0, nw.length - 2);
          } else if (nw.endsWith("s") && nw.length > 1) {
            rootNw = nw.substring(0, nw.length - 1);
          }
          if (kw.contains(rootNw) || rootNw.contains(kw)) return true;
        }
        
        return false;
      });
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final queryLower = _searchQuery.toLowerCase();
      filteredProducts.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        
        // 1. Exact match
        final aExact = aName == queryLower;
        final bExact = bName == queryLower;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        
        // 2. Starts with
        final aStarts = aName.startsWith(queryLower);
        final bStarts = bName.startsWith(queryLower);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        
        // 3. Contains match
        final aContains = aName.contains(queryLower);
        final bContains = bName.contains(queryLower);
        if (aContains && !bContains) return -1;
        if (!aContains && bContains) return 1;
        
        // Fallback to name sorting
        return aName.compareTo(bName);
      });
    }

    // Trending searches list matching screenshot 5
    final List<String> trendingSearches = [
      'Tomatoes',
      'Banana',
      'Paneer',
      'Bread',
      'Milk',
      'Rice',
    ];

    // All categories list matching screenshot 5
    final List<Map<String, dynamic>> categoryList = [
      {'name': 'Vegetables', 'icon': Icons.eco_outlined, 'color': Colors.green},
      {'name': 'Fruits', 'icon': Icons.apple, 'color': Colors.red},
      {'name': 'Dairy', 'icon': Icons.egg_alt_outlined, 'color': Colors.blue},
      {'name': 'Bakery', 'icon': Icons.bakery_dining_outlined, 'color': Colors.orange},
      {'name': 'Snacks', 'icon': Icons.cookie_outlined, 'color': Colors.amber},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE8F5E9), width: 1.5),
            ),
            child: TextField(
              controller: _queryController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
                _updateSearchActivity(val.trim());
              },
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  _saveRecentSearch(val.trim());
                }
              },
              style: const TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search vegetables, fruits, dairy...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _queryController.clear();
                          setState(() {
                            _searchQuery = "";
                          });
                          _updateSearchActivity("");
                        },
                        child: Icon(
                          Icons.cancel,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.08),
      ),
      body: _searchQuery.isEmpty
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. RECENT SEARCHES SECTION (if not empty)
                  if (_recentSearches.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history, color: AppColors.primary, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Recent Searches',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _clearRecentSearches,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: _recentSearches.map((query) {
                        return GestureDetector(
                          onTap: () => _handleSearchTap(query, allProducts),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200, width: 1.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history, size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text(
                                  query,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // 1. TRENDING SEARCHES HEADING & WRAP CHIPS
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.orange, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'Trending Searches',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: trendingSearches.map((tag) {
                      return GestureDetector(
                        onTap: () => _handleSearchTap(tag, allProducts),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4FBF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE8F5E9), width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // 2. ALL CATEGORIES LIST INDEX
                  Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Shop by Categories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE8F5E9), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categoryList.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final cat = categoryList[index];
                        final Color catColor = cat['color'] as Color;

                        return ListTile(
                          onTap: () {
                            appState.setSelectedCategoryByName(cat['name'] as String);
                            appState.setNavIndex(1);
                            Navigator.pop(context); // Go to categories in home shell
                          },
                          hoverColor: const Color(0xFFF9FBF9),
                          leading: Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(cat['icon'] as IconData, color: catColor, size: 18),
                          ),
                          title: Text(
                            cat['name'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          : filteredProducts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'Coming Soon!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'We are expanding our catalog to include this item soon.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final selectedUnit = appState.getProductSelectedUnit(product);
                    final prices = appState.getProductPriceForUnit(product, selectedUnit);
                    final activePrice = prices['price']!;
                    final activeOriginalPrice = prices['originalPrice']!;
                    final cartQty = appState.getProductQuantity(product.id, selectedUnit: selectedUnit);

                    return GestureDetector(
                      onTap: () {
                        if (_searchQuery.isNotEmpty) {
                          _saveRecentSearch(_searchQuery);
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(product: product),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8F5E9), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Product Image Container
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 68,
                                height: 68,
                                color: const Color(0xFFF9FBF9),
                                padding: const EdgeInsets.all(4),
                                child: ProductImage(
                                  imageUrl: product.imageUrl,
                                  fit: BoxFit.contain,
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
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
                            // Favorite
                            GestureDetector(
                              onTap: () {
                                appState.toggleFavorite(product.id);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFF8F8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  appState.isFavorite(product.id) ? Icons.favorite : Icons.favorite_border,
                                  color: appState.isFavorite(product.id) ? Colors.red : Colors.grey.shade400,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Add to cart buttons
                            !appState.isProductInStock(product.id)
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300, width: 0.8),
                                    ),
                                    child: Text(
                                      'SOLD OUT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  )
                                : cartQty == 0
                                    ? SizedBox(
                                        height: 32,
                                        width: 72,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            appState.addToCart(
                                              product,
                                              selectedUnit: selectedUnit,
                                              price: activePrice,
                                              originalPrice: activeOriginalPrice,
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: EdgeInsets.zero,
                                            backgroundColor: Colors.white,
                                            foregroundColor: AppColors.primary,
                                          ),
                                          child: const Text(
                                            'ADD',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => appState.removeFromCart(product, selectedUnit: selectedUnit),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                child: Icon(Icons.remove, color: Colors.white, size: 14),
                                              ),
                                            ),
                                            GestureDetector(
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
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const Icon(Icons.arrow_drop_down, color: Colors.white, size: 12),
                                                ],
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => appState.addToCart(
                                                product,
                                                selectedUnit: selectedUnit,
                                                price: activePrice,
                                                originalPrice: activeOriginalPrice,
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                child: Icon(Icons.add, color: Colors.white, size: 14),
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
    );
  }
}
