class ProductVariant {
  final String id;
  final String productId;
  final double weight;
  final String unit;
  final double mrp;
  final double sellingPrice;
  final String sku;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.weight,
    required this.unit,
    required this.mrp,
    required this.sellingPrice,
    required this.sku,
  });
}

class ProductVariantOption {
  final String unit;
  final double price;
  final double originalPrice;

  const ProductVariantOption({
    required this.unit,
    required this.price,
    required this.originalPrice,
  });

  Map<String, dynamic> toJson() => {
    'unit': unit,
    'price': price,
    'originalPrice': originalPrice,
  };

  factory ProductVariantOption.fromJson(Map<String, dynamic> json) => ProductVariantOption(
    unit: json['unit'] ?? '',
    price: (json['price'] ?? 0.0).toDouble(),
    originalPrice: (json['originalPrice'] ?? 0.0).toDouble(),
  );
}

class Product {
  final String id; // Represents the Variant ID for cart/favorites
  final String productId; // Parent product ID
  final String name;
  final String unit;
  final double price;
  final double originalPrice;
  final String imageUrl;
  final double rating;
  final int ratingCount;
  final String category;
  final String subCategoryId; // Sub-Category identifier
  final String description;
  final bool isOrganic;
  final String status;
  final int stock;
  final List<ProductVariantOption>? variants;

  Product({
    required this.id,
    this.productId = '',
    required this.name,
    required this.unit,
    required this.price,
    required this.originalPrice,
    required this.imageUrl,
    required this.rating,
    required this.ratingCount,
    required this.category,
    this.subCategoryId = '',
    required this.description,
    this.isOrganic = false,
    this.status = 'active',
    this.stock = 50,
    this.variants,
  });

  bool get isSoldOut => stock <= 0 || status == 'sold_out' || status == 'inactive';

  int get discountPercent {
    if (originalPrice <= 0 || price >= originalPrice) return 0;
    return (((originalPrice - price) / originalPrice) * 100).round();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'name': name,
    'unit': unit,
    'price': price,
    'originalPrice': originalPrice,
    'imageUrl': imageUrl,
    'rating': rating,
    'ratingCount': ratingCount,
    'category': category,
    'subCategoryId': subCategoryId,
    'description': description,
    'isOrganic': isOrganic,
    'status': status,
    'stock': stock,
    'variants': variants?.map((v) => v.toJson()).toList(),
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] ?? '',
    productId: json['productId'] ?? '',
    name: json['name'] ?? '',
    unit: json['unit'] ?? '',
    price: (json['price'] ?? 0.0).toDouble(),
    originalPrice: (json['originalPrice'] ?? 0.0).toDouble(),
    imageUrl: json['imageUrl'] ?? '',
    rating: (json['rating'] ?? 4.5).toDouble(),
    ratingCount: json['ratingCount'] ?? 0,
    category: json['category'] ?? '',
    subCategoryId: json['subCategoryId'] ?? '',
    description: json['description'] ?? '',
    isOrganic: json['isOrganic'] ?? false,
    status: json['status'] ?? 'active',
    stock: json['stock'] ?? 50,
    variants: json['variants'] != null
        ? (json['variants'] as List<dynamic>)
            .map((v) => ProductVariantOption.fromJson(v as Map<String, dynamic>))
            .toList()
        : null,
  );
}

class CartItem {
  final Product product;
  int quantity;
  final String selectedUnit;
  final double price;
  final double originalPrice;

  CartItem({
    required this.product,
    required this.quantity,
    String? selectedUnit,
    double? price,
    double? originalPrice,
  })  : this.selectedUnit = selectedUnit ?? product.unit,
        this.price = price ?? product.price,
        this.originalPrice = originalPrice ?? product.originalPrice;

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? selectedUnit,
    double? price,
    double? originalPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedUnit: selectedUnit ?? this.selectedUnit,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
    );
  }

  double get totalProductPrice => price * quantity;
}

class Address {
  final String id;
  final String title;
  final String fullName;
  final String mobile;
  final String addressLine;
  final String landmark;
  final String city;
  final String pinCode;
  bool isSelected;

  Address({
    required this.id,
    required this.title,
    required this.fullName,
    required this.mobile,
    required this.addressLine,
    required this.landmark,
    required this.city,
    required this.pinCode,
    this.isSelected = false,
  });

  Address copyWith({
    String? id,
    String? title,
    String? fullName,
    String? mobile,
    String? addressLine,
    String? landmark,
    String? city,
    String? pinCode,
    bool? isSelected,
  }) {
    return Address(
      id: id ?? this.id,
      title: title ?? this.title,
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      addressLine: addressLine ?? this.addressLine,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      pinCode: pinCode ?? this.pinCode,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fullName': fullName,
        'mobile': mobile,
        'addressLine': addressLine,
        'landmark': landmark,
        'city': city,
        'pinCode': pinCode,
        'isSelected': isSelected,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        fullName: json['full_name'] ?? json['fullName'] ?? '',
        mobile: json['mobile'] ?? '',
        addressLine: json['address_line'] ?? json['addressLine'] ?? '',
        landmark: json['landmark'] ?? '',
        city: json['city'] ?? '',
        pinCode: json['pin_code'] ?? json['pinCode'] ?? '',
        isSelected: json['is_selected'] ?? json['isSelected'] ?? false,
      );
}

class Order {
  final String id;
  final DateTime date;
  final String status; // 'Ongoing', 'Delivered', 'Cancelled'
  final List<CartItem> items;
  final double totalAmount;
  final String deliveryTime;
  final String paymentMethod; // 'ONLINE' or 'COD'
  final String paymentStatus; // 'paid' or 'pending'
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;

  Order({
    required this.id,
    required this.date,
    required this.status,
    required this.items,
    required this.totalAmount,
    required this.deliveryTime,
    this.paymentMethod = 'COD',
    this.paymentStatus = 'pending',
    this.customerName = '',
    this.customerPhone = '',
    this.deliveryAddress = '',
  });
}

class Outlet {
  final String id;
  final String name;
  final String address;
  final bool isActive;

  Outlet({
    required this.id,
    required this.name,
    required this.address,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'is_active': isActive,
      };

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        address: json['address'] ?? '',
        isActive: json['is_active'] ?? true,
      );
}

class SubCategory {
  final String id;
  final String categoryId;
  final String name;
  final String imageUrl;

  SubCategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'name': name,
        'image_url': imageUrl,
      };

  factory SubCategory.fromJson(Map<String, dynamic> json) => SubCategory(
        id: json['id'] ?? '',
        categoryId: json['category_id'] ?? '',
        name: json['name'] ?? '',
        imageUrl: json['image_url'] ?? '',
      );
}

class CategoryItem {
  final String id;
  final String name;
  final String imageUrl;
  final String status;
  final int displayOrder;

  CategoryItem({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.status = 'active',
    this.displayOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'status': status,
        'display_order': displayOrder,
      };

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString() ?? '';
    final String name = json['name']?.toString() ?? '';
    String img = json['image_url']?.toString() ?? json['image']?.toString() ?? '';
    
    if (img.isEmpty || img == 'null') {
      final nameLower = name.toLowerCase();
      if (nameLower.contains('veg')) {
        img = 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Veggies.webp';
      } else if (nameLower.contains('fruit')) {
        img = 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Fruits.webp';
      } else if (nameLower.contains('dairy') || nameLower.contains('diar')) {
        img = 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Diary.webp';
      } else if (nameLower.contains('bakery')) {
        img = 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Bakery.webp';
      } else if (nameLower.contains('snack')) {
        img = 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Snacks.webp';
      } else if (nameLower.contains('beverag')) {
        img = 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Beverages.webp';
      } else {
        img = 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Veggies.webp';
      }
    }

    return CategoryItem(
      id: id,
      name: name,
      imageUrl: img,
      status: json['status']?.toString() ?? 'active',
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
    );
  }
}

class CouponOffer {
  final String code;
  final String title;
  final String desc;
  final double minAmount;
  final String imageUrl;
  final double discountPercent;
  final double discountAmount;
  final bool isFreeDelivery;
  final bool isBrandAddon;
  final String? brandName;
  final String status;

  const CouponOffer({
    required this.code,
    required this.title,
    required this.desc,
    required this.minAmount,
    required this.imageUrl,
    this.discountPercent = 0.0,
    this.discountAmount = 0.0,
    this.isFreeDelivery = false,
    this.isBrandAddon = false,
    this.brandName,
    this.status = 'active',
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'title': title,
    'description': desc,
    'min_order': minAmount,
    'min_order_amount': minAmount,
    'image_url': imageUrl,
    'type': discountPercent > 0 ? 'percentage' : 'flat',
    'discount_type': discountPercent > 0 ? 'percentage' : 'flat',
    'value': discountPercent > 0 ? (discountPercent * 100.0) : discountAmount,
    'discount_value': discountPercent > 0 ? (discountPercent * 100.0) : discountAmount,
    'status': status,
  };

  factory CouponOffer.fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString() ?? '';
    final type = json['type']?.toString() ?? json['discount_type']?.toString() ?? 'flat';
    final val = double.tryParse(json['value']?.toString() ?? json['discount_value']?.toString() ?? '0') ?? 0.0;
    final minOrd = double.tryParse(json['min_order']?.toString() ?? json['min_order_amount']?.toString() ?? '0') ?? 0.0;
    final status = json['status']?.toString() ?? 'active';
    final expiryStr = json['expiry_date']?.toString();
    
    // Check if expired dynamically
    String finalStatus = status;
    if (expiryStr != null && expiryStr.isNotEmpty) {
      try {
        final expiry = DateTime.parse(expiryStr);
        if (expiry.isBefore(DateTime.now())) {
          finalStatus = 'expired';
        }
      } catch (_) {}
    }
    
    return CouponOffer(
      code: code,
      title: json['title']?.toString() ?? 'GET ${type == 'percentage' ? '${val.toInt()}% OFF' : '₹${val.toInt()} OFF'}',
      desc: json['description']?.toString() ?? json['desc']?.toString() ?? 'Use code $code on orders above ₹${minOrd.toInt()}',
      minAmount: minOrd,
      imageUrl: json['image_url']?.toString() ?? 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Veggies.webp',
      discountPercent: type == 'percentage' ? (val / 100.0) : 0.0,
      discountAmount: type != 'percentage' ? val : 0.0,
      isBrandAddon: false,
      status: finalStatus,
    );
  }
}

