import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool get isSupabaseAvailable {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get client => isSupabaseAvailable ? Supabase.instance.client : null;

  String? _currentUserId;
  void setCurrentUserId(String? id) => _currentUserId = id;
  String get currentUserId => _currentUserId ?? '';

  final Map<String, String> _productImageCache = {};

  // -------------------------------------------------------------
  // Authentication / Profile Sync
  // -------------------------------------------------------------
  Future<void> syncUserProfile(String mobile, String name, {String? email}) async {
    if (!isSupabaseAvailable) return;
    try {
      await client!.from('users').upsert({
        'id': mobile,
        'full_name': name,
        'mobile': mobile,
        'email': email,
        'status': 'active',
        'profile_completion_status': 'complete',
      });
      print("Synced profile to Supabase successfully.");
    } catch (e) {
      print("Failed to sync profile to Supabase: $e");
    }
  }

  // -------------------------------------------------------------
  // Product Seeding & Fetching Methods
  // -------------------------------------------------------------
  Future<void> seedProductsIfNeeded(List<Product> mockProducts, {bool forceUpdate = false}) async {
    if (!isSupabaseAvailable) return;
    try {
      if (!forceUpdate) {
        final check = await client!.from('products').select('id').limit(1);
        if (check.isNotEmpty) return; // already seeded
      }

      print("Seeding categories and products to Supabase...");
      
      final List<String> categoriesToSeed = [
        'Vegetables', 'Fruits', 'Dairy', 'Bakery', 'Snacks', 'Beverages'
      ];
      
      final List<Map<String, dynamic>> categoryRows = categoriesToSeed.map((name) {
        return {
          'id': name.toLowerCase().replaceAll(' ', '_'),
          'name': name,
          'status': 'active',
        };
      }).toList();
      
      await client!.from('categories').upsert(categoryRows);
      
      // 1b. Seed Sub-Categories
      final List<Map<String, dynamic>> subCategoryRows = [
        {
          'id': 'leafy_vegetables',
          'category_id': 'vegetables',
          'name': 'Leafy Vegetables',
          'image_url': 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Leafy%20Veggies.webp',
        },
        {
          'id': 'root_vegetables',
          'category_id': 'vegetables',
          'name': 'Root Vegetables',
          'image_url': 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Root%20Vegies.webp',
        },
        {
          'id': 'organic_vegetables',
          'category_id': 'vegetables',
          'name': 'Organic Vegetables',
          'image_url': 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Veggies.webp',
        },
        {
          'id': 'fresh_fruits',
          'category_id': 'fruits',
          'name': 'Fresh Fruits',
          'image_url': 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Fresh%20Fruits.webp',
        },
        {
          'id': 'fresh_milk',
          'category_id': 'dairy',
          'name': 'Fresh Milk',
          'image_url': 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Fresh%20Dairy.webp',
        },
        {
          'id': 'cakes',
          'category_id': 'bakery',
          'name': 'Cakes',
          'image_url': 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Cakes.webp',
        },
      ];
      try {
        await client!.from('sub_categories').upsert(subCategoryRows);
      } catch (e) {
        print("Failed to seed subcategories: $e");
      }
      
      // 2. Seed Products & Variants
      for (var product in mockProducts) {
        final catId = product.category.toLowerCase().replaceAll(' ', '_');
        final parentId = product.productId.isNotEmpty ? product.productId : 'prod_${product.id}';
        
        // Insert product (STRICT COLUMNS ONLY: id, category_id, sub_category_id, name, description, is_organic, status, image_url)
        await client!.from('products').upsert({
          'id': parentId,
          'category_id': catId,
          'sub_category_id': product.subCategoryId.isNotEmpty ? product.subCategoryId : null,
          'name': product.name,
          'description': product.description,
          'is_organic': product.isOrganic,
          'status': 'active',
          'image_url': product.imageUrl,
        });

        // Redundant write to organic_products is skipped. The is_organic flag is already successfully saved in the main products table.
        
        
        // Parse weight and unit from unit string
        double weight = 1.0;
        String unit = 'kg';
        try {
          final parts = product.unit.split(' ');
          if (parts.isNotEmpty) {
            weight = double.tryParse(parts[0]) ?? 1.0;
            if (parts.length > 1) {
              final rawUnit = parts[1].toLowerCase();
              if (rawUnit == 'g') unit = 'g';
              else if (rawUnit == 'pcs' || rawUnit == 'pieces' || rawUnit == 'piece') unit = 'pcs';
              else if (rawUnit == 'kg') unit = 'kg';
              else unit = 'pcs';
            }
          }
        } catch (_) {}

        // Insert variant
        await client!.from('product_variants').upsert({
          'id': product.id,
          'product_id': parentId,
          'weight': weight,
          'unit': unit,
          'mrp': product.originalPrice,
          'selling_price': product.price,
          'sku': 'SKU_${product.id.toUpperCase()}',
        });
      }
      print("Seeding completed successfully!");
    } catch (e) {
      print("Failed to seed products to Supabase: $e");
    }
  }

  // Dynamic image fallbacks to preserve UI layout without adding database columns
  String getFallbackProductImage(String productName, String category) {
    // Return a generic, neutral grocery/shopping cart placeholder image
    return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500';
  }

  Future<List<Product>> fetchProducts(List<Product> fallbackProducts) async {
    if (!isSupabaseAvailable) return fallbackProducts;
    try {
      var response = await client!
          .from('products')
          .select('*, categories(name), product_variants(*)');
          
      if (response.isEmpty) {
        await seedProductsIfNeeded(fallbackProducts);
        return fallbackProducts;
      }

      final bool hasNullImages = response.any((row) => row['image_url'] == null);
      final bool needsSubCategorySync = response.any((row) => row['name'] == 'Cabbage' && row['sub_category_id'] == null);
      final bool needsOrganicSync = response.any((row) => row['name'] == 'Cabbage' && !(row['is_organic'] ?? false));
      if (hasNullImages || needsSubCategorySync || needsOrganicSync) {
        print("Detected products with missing metadata. Re-seeding database metadata...");
        await seedProductsIfNeeded(fallbackProducts, forceUpdate: true);
        final reFetched = await client!
            .from('products')
            .select('*, categories(name), product_variants(*)');
        if (reFetched.isNotEmpty) {
          response = reFetched;
        }
      }

      // Fetch organic product IDs from the organic_products table
      final Set<String> organicProductIds = {};
      try {
        final organicResponse = await client!.from('organic_products').select('product_id');
        for (var row in organicResponse) {
          if (row['product_id'] != null) {
            organicProductIds.add(row['product_id'].toString());
          }
        }
      } catch (e) {
        print("Failed to fetch organic product IDs (silent): $e");
      }
      
      final List<Product> productsList = [];
      for (var row in response) {
        final catData = row['categories'];
        final String categoryName = catData != null ? (catData['name'] ?? 'All') : 'All';

        final List<dynamic> variantsData = row['product_variants'] as List<dynamic>? ?? [];
        if (variantsData.isEmpty) {
          continue;
        }

        final String parentId = row['id'].toString();
        final bool isOrganicProduct = organicProductIds.contains(parentId) || (row['is_organic'] ?? false);

        // Group all variants into structured ProductVariantOption objects
        final List<ProductVariantOption> variantOptions = [];
        int totalStock = 0;
        for (var vRow in variantsData) {
          final double weight = double.tryParse(vRow['weight']?.toString() ?? '1') ?? 1.0;
          final String rawUnit = (vRow['unit']?.toString() ?? 'kg').trim();
          final String formattedWeight = weight == weight.toInt() ? weight.toInt().toString() : weight.toString();
          final String unitStr = rawUnit.isEmpty ? formattedWeight : '$formattedWeight $rawUnit';
          final double sPrice = (vRow['selling_price'] ?? 0.0).toDouble();
          final double mrp = (vRow['mrp'] ?? 0.0).toDouble();
          final int vStock = int.tryParse(vRow['stock_total']?.toString() ?? '50') ?? 0;
          totalStock += vStock;

          variantOptions.add(ProductVariantOption(
            unit: unitStr,
            price: sPrice,
            originalPrice: mrp > 0 ? mrp : sPrice,
          ));
        }

        final primaryVariant = variantsData.first;
        final primaryStock = int.tryParse(primaryVariant['stock_total']?.toString() ?? '50') ?? 0;
        final double pWeight = double.tryParse(primaryVariant['weight']?.toString() ?? '1') ?? 1.0;
        final String pUnit = (primaryVariant['unit']?.toString() ?? 'kg').trim();
        final String formattedPWeight = pWeight == pWeight.toInt() ? pWeight.toInt().toString() : pWeight.toString();
        final String primaryUnitStr = pUnit.isEmpty ? formattedPWeight : '$formattedPWeight $pUnit';
        final bool isInactiveOrSold = (totalStock <= 0 && primaryStock <= 0) || row['status'] == 'sold_out' || row['status'] == 'inactive';

        final String resolvedImageUrl = (row['image_url'] != null && row['image_url'].toString().isNotEmpty)
            ? row['image_url']
            : getFallbackProductImage(row['name'] ?? '', categoryName);

        _productImageCache[parentId] = resolvedImageUrl;
        _productImageCache[(row['name'] ?? '').toString().toLowerCase()] = resolvedImageUrl;
        for (var v in variantsData) {
          if (v['id'] != null) {
            _productImageCache[v['id'].toString()] = resolvedImageUrl;
          }
        }

        productsList.add(Product(
          id: primaryVariant['id'].toString(), // Primary variant ID (matches product ID in single-variant cases)
          productId: parentId, // Parent Product ID
          name: row['name'] ?? '',
          unit: primaryUnitStr,
          price: (primaryVariant['selling_price'] ?? 0.0).toDouble(),
          originalPrice: (primaryVariant['mrp'] ?? 0.0).toDouble(),
          imageUrl: resolvedImageUrl,
          rating: 4.5,
          ratingCount: 50,
          category: categoryName,
          subCategoryId: row['sub_category_id'] ?? '',
          description: row['description'] ?? '',
          isOrganic: isOrganicProduct,
          status: isInactiveOrSold ? 'sold_out' : (row['status'] ?? 'active'),
          stock: totalStock > 0 ? totalStock : primaryStock,
          variants: variantOptions.isNotEmpty ? variantOptions : null,
        ));
      }
      return productsList;
    } catch (e) {
      print("Failed to fetch products from Supabase, falling back to mock: $e");
      return fallbackProducts;
    }
  }

  Future<List<CategoryItem>> fetchCategories() async {
    if (!isSupabaseAvailable) return [];
    try {
      final response = await client!.from('categories').select('*');
      final list = response.map<CategoryItem>((row) => CategoryItem.fromJson(row)).toList();
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return list;
    } catch (e) {
      print("Failed to fetch categories: $e");
      return [];
    }
  }

  Future<List<SubCategory>> fetchSubCategories() async {
    if (!isSupabaseAvailable) return [];
    try {
      final response = await client!.from('sub_categories').select('*');
      return response.map<SubCategory>((row) => SubCategory.fromJson(row)).toList();
    } catch (e) {
      print("Failed to fetch subcategories: $e");
      return [];
    }
  }

  Future<List<CouponOffer>> fetchCoupons() async {
    if (!isSupabaseAvailable) return [];
    try {
      final response = await client!.from('coupons').select('*');
      return response.map<CouponOffer>((row) => CouponOffer.fromJson(row)).toList();
    } catch (e) {
      print("Failed to fetch coupons: $e");
      return [];
    }
  }

  // -------------------------------------------------------------
  // Address Database Sync Methods
  // -------------------------------------------------------------
  Stream<List<Address>> listenToAddresses(String userId) {
    if (!isSupabaseAvailable || userId.isEmpty) {
      return Stream.value([]);
    }

    final controller = StreamController<List<Address>>();

    Future<void> fetchAndEmit() async {
      try {
        final list = await getAddresses(userId);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        print("Error fetching addresses: $e");
      }
    }

    // Immediate initial fetch from database
    fetchAndEmit();

    try {
      final sub = client!
          .from('addresses')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .listen(
            (rows) {
              final list = rows.map<Address>((row) {
                return Address(
                  id: row['id'].toString(),
                  title: row['title'] ?? 'Address',
                  fullName: row['full_name'] ?? '',
                  mobile: row['mobile'] ?? '',
                  addressLine: row['address_line'] ?? '',
                  landmark: row['landmark'] ?? '',
                  city: row['city'] ?? '',
                  pinCode: row['pin_code'] ?? '',
                  isSelected: row['is_selected'] ?? false,
                );
              }).toList();
              if (!controller.isClosed) {
                controller.add(list);
              }
            },
            onError: (err) {
              print("Realtime not enabled on addresses table (graceful fallback): $err");
              fetchAndEmit();
            },
          );

      controller.onCancel = () {
        sub.cancel();
        controller.close();
      };
    } catch (e) {
      print("Failed to listen to addresses from Supabase: $e");
      fetchAndEmit();
    }

    return controller.stream;
  }

  Future<List<Address>> getAddresses(String userId) async {
    if (!isSupabaseAvailable || userId.isEmpty) return [];
    try {
      final res = await client!.from('addresses').select('*').eq('user_id', userId);
      return (res as List).map<Address>((row) {
        return Address(
          id: row['id'].toString(),
          title: row['title'] ?? 'Address',
          fullName: row['full_name'] ?? '',
          mobile: row['mobile'] ?? '',
          addressLine: row['address_line'] ?? '',
          landmark: row['landmark'] ?? '',
          city: row['city'] ?? '',
          pinCode: row['pin_code'] ?? '',
          isSelected: row['is_selected'] ?? false,
        );
      }).toList();
    } catch (e) {
      print("getAddresses failed: $e");
      return [];
    }
  }

  Future<void> saveAddress(String userId, Address address) async {
    if (!isSupabaseAvailable || userId.isEmpty) return;
    try {
      // First ensure user exists in users table
      await client!.from('users').upsert({
        'id': userId,
        'mobile': userId,
        'full_name': address.fullName.isNotEmpty ? address.fullName : 'Customer',
        'status': 'active',
      });

      // If current address is selected, unselect all other user addresses in DB first
      if (address.isSelected) {
        await client!
            .from('addresses')
            .update({'is_selected': false})
            .eq('user_id', userId);
      }

      final Map<String, dynamic> data = {
        'user_id': userId,
        'title': address.title,
        'full_name': address.fullName,
        'mobile': address.mobile,
        'address_line': address.addressLine,
        'landmark': address.landmark,
        'city': address.city,
        'pin_code': address.pinCode,
        'is_selected': address.isSelected,
      };

      final isUuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(address.id);
      if (isUuid) data['id'] = address.id;

      await client!.from('addresses').upsert(data);
    } catch (e) {
      print("Failed to save address to Supabase: $e");
    }
  }

  Future<void> deleteAddress(String userId, String addressId) async {
    if (!isSupabaseAvailable || userId.isEmpty) return;
    try {
      final isUuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(addressId);
      if (!isUuid) return;

      await client!.from('addresses').delete().eq('id', addressId);
      print("Deleted address from Supabase successfully.");
    } catch (e) {
      print("Failed to delete address from Supabase: $e");
    }
  }

  // -------------------------------------------------------------
  // Order Database Sync Methods
  // -------------------------------------------------------------
  Stream<List<Order>> listenToOrders(String userId) {
    if (!isSupabaseAvailable || userId.isEmpty) {
      return Stream.value([]);
    }

    final controller = StreamController<List<Order>>();

    Future<void> fetchAndEmit() async {
      try {
        final response = await client!
            .from('orders')
            .select('*, order_items(*)')
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final List<Order> orders = [];
        for (var row in response) {
          final rawItems = row['order_items'] as List<dynamic>? ?? [];
          final List<CartItem> parsedItems = rawItems.map<CartItem>((itemRow) {
            final String productName = (itemRow['product_name'] ?? 'Catalog Item').toString();
            final String weight = (itemRow['weight'] ?? '1').toString();
            final String unit = (itemRow['unit'] ?? 'pcs').toString();
            final double price = (itemRow['price'] ?? 0.0).toDouble();
            final int quantity = (itemRow['quantity'] ?? 1) as int;
            final String variantId = (itemRow['variant_id'] ?? '').toString();
            final String displayUnit = '$weight $unit'.trim();
            final String imageUrl = _productImageCache[variantId] ??
                _productImageCache[productName.toLowerCase()] ??
                getFallbackProductImage(productName, 'All');

            return CartItem(
              product: Product(
                id: variantId.isNotEmpty ? variantId : (itemRow['id']?.toString() ?? 'unknown'),
                productId: variantId,
                name: productName,
                unit: displayUnit.isNotEmpty ? displayUnit : 'Unit',
                price: price,
                originalPrice: price,
                imageUrl: imageUrl,
                rating: 4.5,
                ratingCount: 50,
                category: 'All',
                description: '',
              ),
              quantity: quantity,
            );
          }).toList();

          orders.add(Order(
            id: row['id'],
            date: DateTime.parse(row['created_at']),
            status: row['order_status'] ?? 'placed',
            items: parsedItems,
            totalAmount: (row['total'] ?? 0.0).toDouble(),
            deliveryTime: '14 mins',
            paymentMethod: row['payment_method'] ?? 'COD',
            paymentStatus: row['payment_status'] ?? ((row['payment_method'] == 'ONLINE') ? 'paid' : 'pending'),
            deliveryAddress: row['delivery_address'] ?? '',
          ));
        }
        if (!controller.isClosed) {
          controller.add(orders);
        }
      } catch (e) {
        print("Error fetching orders from Supabase: $e");
      }
    }

    // Trigger initial fetch
    fetchAndEmit();

    // Listen to changes on the orders table
    final subscription = client!
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) {
          fetchAndEmit();
        }, onError: (err) {
          print("Orders realtime stream error (handled): $err");
        });

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<void> placeOrder(
    String userId,
    Order order,
    String addressId, {
    String paymentMethod = 'cod',
    double deliveryFee = 0,
    String? deliveryAddress,
  }) async {
    if (!isSupabaseAvailable || userId.isEmpty) return;
    try {
      // Ensure user exists before inserting order (FK: orders.user_id -> users.id)
      await client!.from('users').upsert({
        'id': userId,
        'mobile': userId,
        'status': 'active',
      });

      final String pmLower = paymentMethod.toLowerCase();
      final String normalizedPayment;
      final String paymentStatusVal;
      if (pmLower == 'cod') {
        normalizedPayment = 'COD';
        paymentStatusVal = 'pending';
      } else if (pmLower == 'upi') {
        normalizedPayment = 'UPI';
        paymentStatusVal = 'paid';
      } else if (pmLower == 'card' || pmLower.contains('card') || pmLower.contains('debit') || pmLower.contains('credit')) {
        normalizedPayment = 'CARD';
        paymentStatusVal = 'paid';
      } else if (pmLower == 'wallet') {
        normalizedPayment = 'WALLET';
        paymentStatusVal = 'paid';
      } else {
        normalizedPayment = paymentMethod.toUpperCase();
        paymentStatusVal = 'paid';
      }

      // 1. Insert parent Order
      await client!.from('orders').insert({
        'id': order.id,
        'order_number': 'ORD-${order.id.replaceAll(RegExp(r'[^0-9]'), '')}',
        'user_id': userId,
        'address_id': addressId,
        'total': order.totalAmount,
        'payment_status': paymentStatusVal,
        'payment_method': normalizedPayment,
        'order_status': 'placed',
        'delivery_fee': deliveryFee,
        'delivery_address': deliveryAddress,
      });

      // 2. Insert child Order Items (include denormalized fields for admin invoices)
      final List<Map<String, dynamic>> itemsList = order.items.map((item) {
        final String effectiveUnit = item.selectedUnit.isNotEmpty ? item.selectedUnit : item.product.unit;
        final unitParts = effectiveUnit.trim().split(RegExp(r'\s+'));
        final weight = unitParts.isNotEmpty ? unitParts.first : '1';
        final unit = unitParts.length > 1 ? unitParts.sublist(1).join(' ') : (effectiveUnit.isNotEmpty ? effectiveUnit : 'pcs');
        return {
          'order_id': order.id,
          'variant_id': item.product.id,
          'quantity': item.quantity,
          'price': item.price,
          'product_name': item.product.name,
          'weight': weight,
          'unit': unit,
        };
      }).toList();

      await client!.from('order_items').insert(itemsList);
      print("Placed order in Supabase successfully.");

      // 3. Auto-deduct stock in product_variants
      for (var item in order.items) {
        try {
          final varRes = await client!
              .from('product_variants')
              .select('stock_total')
              .eq('id', item.product.id)
              .maybeSingle();
          if (varRes != null) {
            final int currentStock = int.tryParse(varRes['stock_total']?.toString() ?? '0') ?? 0;
            final int newStock = (currentStock - item.quantity).clamp(0, 999999);
            await client!
                .from('product_variants')
                .update({'stock_total': newStock})
                .eq('id', item.product.id);
          }
        } catch (e) {
          print("Stock deduction error for ${item.product.id}: $e");
        }
      }
    } catch (e) {
      print("Failed to place order in Supabase: $e");
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Admin Operations (All Orders & Outlets Sync)
  // -------------------------------------------------------------
  Stream<List<Order>> listenToAllOrders() {
    if (!isSupabaseAvailable) {
      return Stream.value([]);
    }

    final controller = StreamController<List<Order>>();

    Future<void> fetchAndEmit() async {
      try {
        final response = await client!
            .from('orders')
            .select('*, order_items(*)')
            .order('created_at', ascending: false);

        final List<Order> orders = [];
        for (var row in response) {
          final rawItems = row['order_items'] as List<dynamic>? ?? [];
          final List<CartItem> parsedItems = rawItems.map<CartItem>((itemRow) {
            final String productName = (itemRow['product_name'] ?? 'Catalog Item').toString();
            final String weight = (itemRow['weight'] ?? '1').toString();
            final String unit = (itemRow['unit'] ?? 'pcs').toString();
            final double price = (itemRow['price'] ?? 0.0).toDouble();
            final int quantity = (itemRow['quantity'] ?? 1) as int;
            final String variantId = (itemRow['variant_id'] ?? '').toString();
            final String displayUnit = '$weight $unit'.trim();
            final String imageUrl = _productImageCache[variantId] ??
                _productImageCache[productName.toLowerCase()] ??
                getFallbackProductImage(productName, 'All');

            return CartItem(
              product: Product(
                id: variantId.isNotEmpty ? variantId : (itemRow['id']?.toString() ?? 'unknown'),
                productId: variantId,
                name: productName,
                unit: displayUnit.isNotEmpty ? displayUnit : 'Unit',
                price: price,
                originalPrice: price,
                imageUrl: imageUrl,
                rating: 4.5,
                ratingCount: 50,
                category: 'All',
                description: '',
              ),
              quantity: quantity,
            );
          }).toList();

          orders.add(Order(
            id: row['id'],
            date: DateTime.parse(row['created_at']),
            status: row['order_status'] ?? 'placed',
            items: parsedItems,
            totalAmount: (row['total'] ?? 0.0).toDouble(),
            deliveryTime: '14 mins',
            paymentMethod: row['payment_method'] ?? 'COD',
            paymentStatus: row['payment_status'] ?? ((row['payment_method'] == 'ONLINE') ? 'paid' : 'pending'),
            deliveryAddress: row['delivery_address'] ?? '',
          ));
        }
        if (!controller.isClosed) {
          controller.add(orders);
        }
      } catch (e) {
        print("Error fetching all orders from Supabase: $e");
      }
    }

    fetchAndEmit();

    final subscription = client!
        .from('orders')
        .stream(primaryKey: ['id'])
        .listen((_) {
          fetchAndEmit();
        }, onError: (err) {
          print("All orders realtime stream error (handled): $err");
        });

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<List<Outlet>> fetchOutlets(List<Outlet> fallbackOutlets) async {
    if (!isSupabaseAvailable) return fallbackOutlets;
    try {
      final response = await client!.from('outlets').select();
      if (response.isEmpty) {
        // Seed default outlets
        final rows = fallbackOutlets.map((o) => o.toJson()).toList();
        await client!.from('outlets').insert(rows);
        return fallbackOutlets;
      }
      return response.map<Outlet>((row) => Outlet.fromJson(row)).toList();
    } catch (e) {
      print("Failed to fetch outlets from outlets table: $e");
      return fallbackOutlets;
    }
  }

  Future<void> saveOutlet(Outlet outlet) async {
    if (!isSupabaseAvailable) return;
    try {
      await client!.from('outlets').upsert(outlet.toJson());
      print("Saved outlet ${outlet.name} to Supabase successfully.");
    } catch (e) {
      print("Failed to save outlet to Supabase: $e");
      // Fallback: throw so UI/State can notify user or try alternate profile-meta sync
      rethrow;
    }
  }

  // Wishlist sync
  Future<List<String>> fetchWishlist(String userId) async {
    if (!isSupabaseAvailable || userId.isEmpty) return [];
    try {
      final res = await client!.from('wishlists').select('product_id').eq('user_id', userId);
      return res.map<String>((r) => r['product_id'].toString()).toList();
    } catch (e) { print('fetchWishlist: $e'); return []; }
  }

  Future<void> addToWishlist(String userId, String productId) async {
    if (!isSupabaseAvailable || userId.isEmpty) return;
    try {
      await client!.from('wishlists').upsert({'user_id': userId, 'product_id': productId});
    } catch (e) { print('addToWishlist: $e'); }
  }

  Future<void> removeFromWishlist(String userId, String productId) async {
    if (!isSupabaseAvailable || userId.isEmpty) return;
    try {
      await client!.from('wishlists').delete().eq('user_id', userId).eq('product_id', productId);
    } catch (e) { print('removeFromWishlist: $e'); }
  }

  // Cart Sync
  Future<List<Map<String, dynamic>>> fetchCart(String userId) async {
    if (!isSupabaseAvailable || userId.isEmpty) return [];
    try {
      final res = await client!.from('cart').select().eq('user_id', userId);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('fetchCart error: $e');
      return [];
    }
  }

  Future<void> saveCartItem(String userId, String variantId, int quantity, {String? imageUrl}) async {
    if (!isSupabaseAvailable || userId.isEmpty) return;
    try {
      await client!.from('cart').delete().eq('user_id', userId).eq('variant_id', variantId);
      if (quantity > 0) {
        await client!.from('cart').insert({
          'user_id': userId,
          'variant_id': variantId,
          'quantity': quantity,
          'image_url': imageUrl,
        });
      }
    } catch (e) {
      print('saveCartItem error: $e');
    }
  }

  Future<void> removeFromCartFromDb(String userId, String variantId) async {
    if (!isSupabaseAvailable || userId.isEmpty) return;
    try {
      await client!.from('cart').delete().eq('user_id', userId).eq('variant_id', variantId);
    } catch (e) {
      print('removeFromCartFromDb error: $e');
    }
  }

  Future<void> clearCartFromDb(String userId) async {
    if (!isSupabaseAvailable || userId.isEmpty) return;
    try {
      await client!.from('cart').delete().eq('user_id', userId);
    } catch (e) {
      print('clearCartFromDb error: $e');
    }
  }

  Future<void> deleteOutlet(String id) async {
    if (!isSupabaseAvailable) return;
    try {
      await client!.from('outlets').delete().eq('id', id);
      print("Deleted outlet $id from Supabase successfully.");
    } catch (e) {
      print("Failed to delete outlet from Supabase: $e");
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // User Sessions / Activity Tracking (Real-Time Admin Sync)
  // -------------------------------------------------------------
  Future<void> updateUserActivity(String state, {String? searchQuery}) async {
    if (!isSupabaseAvailable || currentUserId.isEmpty) return;
    try {
      await client!.from('user_sessions').upsert({
        'user_id': currentUserId,
        'current_state': state,
        'search_query': searchQuery,
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
        'app_opens': 1,
      }, onConflict: 'user_id');
    } catch (e) {
      // Fail silently or log locally to prevent app crash if database tables aren't setup yet
      print('updateUserActivity error (silent): $e');
    }
  }

  Future<Map<String, dynamic>?> checkUserExists(String mobile) async {
    if (!isSupabaseAvailable) return null;
    try {
      final res = await client!.from('users').select('*').eq('id', mobile).maybeSingle();
      return res;
    } catch (e) {
      print("checkUserExists failed: $e");
      return null;
    }
  }

  Future<void> recordUserLogin(String mobile, {
    required Map<String, dynamic> deviceInfo,
    required bool isNewUser,
  }) async {
    if (!isSupabaseAvailable) return;
    try {
      // 1. Fetch current profile to get current login count and check for device changes
      final current = await checkUserExists(mobile);
      final currentLoginCount = current != null ? (current['login_count'] as int? ?? 0) : 0;
      final currentDevice = current != null ? (current['device_identifier'] as String?) : null;
      
      final String nowStr = DateTime.now().toUtc().toIso8601String();
      
      // Update history if device identifier changed
      List<dynamic> history = [];
      if (current != null && current['device_change_history'] != null) {
        if (current['device_change_history'] is List) {
          history = List.from(current['device_change_history']);
        }
      }
      
      final String newDevice = deviceInfo['device_identifier'] ?? '';
      if (currentDevice != null && currentDevice.isNotEmpty && currentDevice != newDevice) {
        history.add({
          'old_device': currentDevice,
          'new_device': newDevice,
          'timestamp': nowStr,
        });
      }

      final Map<String, dynamic> upsertData = {
        'id': mobile,
        'mobile': mobile,
        'last_login_date': nowStr,
        'last_active_time': nowStr,
        'login_count': currentLoginCount + 1,
        'app_version_used': deviceInfo['app_version'],
        
        // Device info
        'device_brand': deviceInfo['device_brand'],
        'device_model': deviceInfo['device_model'],
        'android_version': deviceInfo['android_version'],
        'app_version': deviceInfo['app_version'],
        'device_identifier': newDevice,
        'screen_resolution': deviceInfo['screen_resolution'],
        'language': deviceInfo['language'],
        'time_zone': deviceInfo['time_zone'],
        'country': deviceInfo['country'],
        'network_type': deviceInfo['network_type'],
        'device_change_history': history,
      };

      if (isNewUser) {
        upsertData['registration_date'] = nowStr;
        upsertData['first_login_date'] = nowStr;
        upsertData['profile_completion_status'] = 'incomplete';
        upsertData['full_name'] = 'User Name'; // default placeholder
        upsertData['email'] = 'user@example.com'; // default placeholder
      }

      await client!.from('users').upsert(upsertData);
      print("recordUserLogin saved successfully for user $mobile.");
    } catch (e) {
      print("recordUserLogin failed: $e");
    }
  }

  Future<void> completeUserProfile(String mobile, String name, String email) async {
    if (!isSupabaseAvailable) return;
    try {
      await client!.from('users').update({
        'full_name': name,
        'email': email,
        'profile_completion_status': 'complete',
      }).eq('id', mobile);
      print("completeUserProfile saved successfully for user $mobile.");
    } catch (e) {
      print("completeUserProfile failed: $e");
    }
  }
}
