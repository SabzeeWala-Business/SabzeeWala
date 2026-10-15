import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/product_image.dart';
import '../services/notification_service.dart';
import '../services/cashfree_service.dart';
import 'package:http/http.dart' as http;

class AppState extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  StreamSubscription<List<Address>>? _addressesSub;
  StreamSubscription<List<Order>>? _ordersSub;
  RealtimeChannel? _catalogSubscription;
  Timer? _heartbeatTimer;

  String _userRole = 'customer';
  String get userRole => _userRole;

  final Set<String> _outOfStockProductIds = {};
  Set<String> get outOfStockProductIds => _outOfStockProductIds;

  String _userCurrentLocation = "123, MG Road, Darbhanga";
  String get userCurrentLocation => _userCurrentLocation;

  bool _hasSelectedLocation = false;
  bool get hasSelectedLocation => _hasSelectedLocation;

  Future<void> setHasSelectedLocation(bool value) async {
    _hasSelectedLocation = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_selected_location', value);
    notifyListeners();
  }

  void updateUserLocation(String newLocation) {
    _userCurrentLocation = newLocation;
    setHasSelectedLocation(true);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('user_current_location', newLocation);
    });
    notifyListeners();
  }

  Future<void> determineAndSetLiveLocation() async {
    try {
      final String loc = await fetchLiveLocation();
      _userCurrentLocation = loc;
      await setHasSelectedLocation(true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_current_location', loc);
      
      // Also save the live location as an Address so it displays in Checkout and is saved!
      final newAddr = Address(
        id: generateUuid(),
        title: 'Current GPS',
        fullName: userName.isNotEmpty ? userName : 'User Name',
        mobile: userMobile ?? '9876543210',
        addressLine: loc,
        landmark: 'Near GPS Coordinates',
        city: 'Darbhanga', // default city
        pinCode: '846004', // default pin
        isSelected: true,
      );
      addAddress(newAddr);
    } catch (e) {
      print("Failed to get live location: $e");
      rethrow;
    }
  }

  Future<String> fetchLiveLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final String name = place.name ?? "";
        final String subLocality = place.subLocality ?? "";
        final String locality = place.locality ?? "";
        final String postalCode = place.postalCode ?? "";

        final List<String> parts = [];
        if (name.isNotEmpty && name != subLocality) parts.add(name);
        if (subLocality.isNotEmpty) parts.add(subLocality);
        if (locality.isNotEmpty) parts.add(locality);
        if (postalCode.isNotEmpty) parts.add(postalCode);

        return parts.isEmpty ? "Current Location" : parts.join(", ");
      }
    } catch (e) {
      print("Geocoding failed: $e");
    }
    return "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
  }

  bool _isAuthLoading = true;
  bool get isAuthLoading => _isAuthLoading;

  AppState() {
    _initCatalog();
    _loadLoginState();
    syncUserBackend();
    _listenToStockUpdates();
    _ensureDefaultAddress();
  }

  void _ensureDefaultAddress() {
    if (_addresses.isEmpty) {
      _addresses.add(Address(
        id: 'default_location_addr',
        title: 'Home',
        fullName: (_userName.isNotEmpty && _userName != 'User Name') ? _userName : 'Customer',
        mobile: _userMobile ?? '9876543210',
        addressLine: _userCurrentLocation.isNotEmpty ? _userCurrentLocation : '123, MG Road, Darbhanga',
        landmark: 'Near City Landmark',
        city: 'Darbhanga',
        pinCode: '846004',
        isSelected: true,
      ));
    } else {
      _userCurrentLocation = selectedAddress?.addressLine ?? _userCurrentLocation;
    }
  }

  Future<void> _loadLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSelectedLocation = prefs.getBool('has_selected_location') ?? false;
      final savedLoc = prefs.getString('user_current_location');
      if (savedLoc != null && savedLoc.isNotEmpty) {
        _userCurrentLocation = savedLoc;
        _hasSelectedLocation = true;
      }
      _walletBalance = prefs.getDouble('wallet_balance') ?? 0.0;

      // Load saved addresses from local cache
      final savedAddressesJson = prefs.getStringList('local_addresses_cache');
      if (savedAddressesJson != null && savedAddressesJson.isNotEmpty) {
        final List<Address> localAddresses = savedAddressesJson.map((str) {
          return Address.fromJson(json.decode(str) as Map<String, dynamic>);
        }).toList();
        
        // Only update if current list is empty to prevent overwriting backend sync
        if (_addresses.isEmpty) {
          _addresses.addAll(localAddresses);
        }
        if (localAddresses.any((a) => a.id != 'default_location_addr')) {
          _hasSelectedLocation = true;
        }
      }
      _ensureDefaultAddress();

      final savedMobile = prefs.getString('user_mobile');
      if (savedMobile != null && savedMobile.isNotEmpty) {
        _userMobile = savedMobile;
        _userName = prefs.getString('user_name') ?? "User Name";
        _userEmail = prefs.getString('user_email') ?? "user@example.com";
        _profileStatus = prefs.getString('profile_status') ?? "incomplete";
        _hasSelectedLocation = true;
        _hasClaimedReferralReward = prefs.getBool('has_claimed_referral_reward_$savedMobile') ?? false;
        syncUserBackend();
        _loadWishlistFromDb(savedMobile);
      }

      if (_hasSelectedLocation) {
        prefs.setBool('has_selected_location', true);
      }
      final savedFavs = prefs.getStringList('favorite_product_ids');
      if (savedFavs != null) {
        _favoriteProductIds.clear();
        _favoriteProductIds.addAll(savedFavs);
      }
    } catch (e) {
      print("Failed to load saved login state: $e");
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  bool _isCatalogLoading = true;
  bool get isCatalogLoading => _isCatalogLoading;

  final List<Outlet> _outlets = [];
  List<Outlet> get outlets => _outlets;

  Future<void> _loadCatalogFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final String? productsJson = prefs.getString('cached_products');
      final String? categoriesJson = prefs.getString('cached_categories');
      final String? subCategoriesJson = prefs.getString('cached_subcategories');
      final String? couponsJson = prefs.getString('cached_coupons');
      final String? outletsJson = prefs.getString('cached_outlets');
      
      if (productsJson != null) {
        final List<dynamic> decoded = jsonDecode(productsJson);
        _products.clear();
        _products.addAll(decoded.map((p) => Product.fromJson(p)).toList());
      }
      if (categoriesJson != null) {
        final List<dynamic> decoded = jsonDecode(categoriesJson);
        _categories.clear();
        _categories.addAll(decoded.map((c) => CategoryItem.fromJson(c)).toList());
      }
      if (subCategoriesJson != null) {
        final List<dynamic> decoded = jsonDecode(subCategoriesJson);
        _subCategories.clear();
        _subCategories.addAll(decoded.map((s) => SubCategory.fromJson(s)).toList());
      }
      if (couponsJson != null) {
        final List<dynamic> decoded = jsonDecode(couponsJson);
        _coupons.clear();
        _coupons.addAll(decoded.map((c) => CouponOffer.fromJson(c)).toList());
      }
      if (outletsJson != null) {
        final List<dynamic> decoded = jsonDecode(outletsJson);
        _outlets.clear();
        _outlets.addAll(decoded.map((o) => Outlet.fromJson(o)).toList());
      }
      
      if (_products.isNotEmpty) {
        syncCartWithCatalog(notify: false);
        _isCatalogLoading = false;
        notifyListeners();
        print("Loaded catalog from local cache successfully. Products count: ${_products.length}");
      }
    } catch (e) {
      print("Failed to load catalog from local cache: $e");
    }
  }

  Future<void> _saveCatalogToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('cached_products', jsonEncode(_products.map((p) => p.toJson()).toList()));
      await prefs.setString('cached_categories', jsonEncode(_categories.map((c) => c.toJson()).toList()));
      await prefs.setString('cached_subcategories', jsonEncode(_subCategories.map((s) => s.toJson()).toList()));
      await prefs.setString('cached_coupons', jsonEncode(_coupons.map((c) => c.toJson()).toList()));
      await prefs.setString('cached_outlets', jsonEncode(_outlets.map((o) => o.toJson()).toList()));
      
      print("Saved catalog to local cache successfully.");
    } catch (e) {
      print("Failed to save catalog to local cache: $e");
    }
  }

  Future<void> _initCatalog() async {
    // 1. Try loading from cache immediately to make app open instantly
    await _loadCatalogFromCache();

    // 2. Fetch fresh catalog data from Supabase in the background
    _fetchFreshCatalogInBackground();

    // 3. Subscribe to real-time database catalog changes
    _subscribeToRealtimeCatalog();
  }

  void _subscribeToRealtimeCatalog() {
    if (!_supabaseService.isSupabaseAvailable) return;
    try {
      _catalogSubscription = _supabaseService.client!
          .channel('realtime-catalog')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            callback: (payload) {
              print("Real-time products change detected! Refreshing catalog...");
              _fetchFreshCatalogInBackground();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'product_variants',
            callback: (payload) {
              print("Real-time product_variants change detected! Refreshing catalog...");
              _fetchFreshCatalogInBackground();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'categories',
            callback: (payload) {
              print("Real-time categories change detected! Refreshing catalog...");
              _fetchFreshCatalogInBackground();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sub_categories',
            callback: (payload) {
              print("Real-time sub_categories change detected! Refreshing catalog...");
              _fetchFreshCatalogInBackground();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'coupons',
            callback: (payload) {
              print("Real-time coupons change detected! Refreshing catalog...");
              _fetchFreshCatalogInBackground();
            },
          );
      _catalogSubscription?.subscribe();
      print("Subscribed to real-time catalog changes successfully.");
    } catch (e) {
      print("Failed to subscribe to real-time catalog: $e");
    }
  }

  Future<void> _fetchFreshCatalogInBackground() async {
    try {
      if (_supabaseService.isSupabaseAvailable) {
        final results = await Future.wait([
          _supabaseService.fetchProducts(List.from(_products)),
          _supabaseService.fetchCategories(),
          _supabaseService.fetchSubCategories(),
          _supabaseService.fetchCoupons(),
        ]);
        final loaded = results[0] as List<Product>;
        final loadedCats = results[1] as List<CategoryItem>;
        final loadedSubCats = results[2] as List<SubCategory>;
        final loadedCoups = results[3] as List<CouponOffer>;

        if (loaded.isNotEmpty) {
          _products.clear();
          _products.addAll(loaded);
          syncCartWithCatalog(notify: false);
        }
        if (loadedCats.isNotEmpty) {
          _categories.clear();
          _categories.addAll(loadedCats);
        }
        if (loadedSubCats.isNotEmpty) {
          _subCategories.clear();
          _subCategories.addAll(loadedSubCats);
        }
        _coupons.clear();
        _coupons.addAll(loadedCoups);
        
        final loadedOutlets = await _supabaseService.fetchOutlets(List.from(_outlets));
        _outlets.clear();
        _outlets.addAll(loadedOutlets);

        // Save new fresh data to local cache
        await _saveCatalogToCache();
      }
    } catch (e) {
      print("Catalog background refresh failed: $e");
    } finally {
      _isCatalogLoading = false;
      notifyListeners();
    }

    // Pre-cache only priority banner & category images smoothly in background
    try {
      for (final cat in _categories.take(6)) {
        if (cat.imageUrl.startsWith('http')) {
          CachedNetworkImageProvider(cat.imageUrl).resolve(const ImageConfiguration());
        }
      }
    } catch (_) {}

    // Cart cache loading / synchronization with live catalog
    if (_cart.isEmpty) {
      await _loadCartLocally();
    } else {
      syncCartWithCatalog(notify: true);
    }
    if (_userMobile != null && _userMobile!.isNotEmpty) {
      await _loadCartFromDb(_userMobile!);
    }
  }

  Future<void> refreshCatalog() async {
    try {
      final loaded = await _supabaseService.fetchProducts(List.from(_products));
      if (_supabaseService.isSupabaseAvailable && loaded.isNotEmpty) {
        _products.clear();
        _products.addAll(loaded);
        syncCartWithCatalog(notify: false);
        
        final loadedCats = await _supabaseService.fetchCategories();
        if (loadedCats.isNotEmpty) {
          _categories.clear();
          _categories.addAll(loadedCats);
        }

        final loadedSubCats = await _supabaseService.fetchSubCategories();
        if (loadedSubCats.isNotEmpty) {
          _subCategories.clear();
          _subCategories.addAll(loadedSubCats);
        }

        final loadedCoups = await _supabaseService.fetchCoupons();
        _coupons.clear();
        _coupons.addAll(loadedCoups);
        
        await _saveCatalogToCache();
        notifyListeners();
      }
    } catch (e) {
      print("Catalog refresh failed: $e");
    }
  }

  Future<void> addOrUpdateOutlet(Outlet outlet) async {
    final index = _outlets.indexWhere((o) => o.id == outlet.id);
    if (index != -1) {
      _outlets[index] = outlet;
    } else {
      _outlets.add(outlet);
    }
    notifyListeners();

    if (_supabaseService.isSupabaseAvailable) {
      try {
        await _supabaseService.saveOutlet(outlet);
      } catch (e) {
        print("Error saving outlet to database: $e");
      }
    }
  }

  Future<void> removeOutlet(String id) async {
    _outlets.removeWhere((o) => o.id == id);
    notifyListeners();

    if (_supabaseService.isSupabaseAvailable) {
      try {
        await _supabaseService.deleteOutlet(id);
      } catch (e) {
        print("Error deleting outlet from database: $e");
      }
    }
  }

  void syncUserBackend() {
    _addressesSub?.cancel();
    _ordersSub?.cancel();
    _heartbeatTimer?.cancel();

    _supabaseService.setCurrentUserId(_userMobile);
    final uid = userMobile ?? _supabaseService.currentUserId;

    if (_supabaseService.isSupabaseAvailable && _userMobile != null && _userMobile!.isNotEmpty) {
      // Periodic user activity heartbeat pinging user_sessions table every 60 seconds
      _supabaseService.updateUserActivity('browsing');
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
        if (_userMobile != null && _userMobile!.isNotEmpty) {
          _supabaseService.updateUserActivity('browsing');
        } else {
          timer.cancel();
        }
      });

      // Check admin_users table first, then users table for role
      _supabaseService.client!
          .from('admin_users')
          .select('role')
          .eq('mobile', _userMobile!)
          .maybeSingle()
          .then((adminRow) async {
        String role = 'customer';
        if (adminRow != null && adminRow['role'] != null) {
          role = adminRow['role'];
        }
        final oldRole = _userRole;
        _userRole = role;
        if (_userRole != oldRole) {
          syncUserBackend();
        } else {
          notifyListeners();
        }
      });
    }

    // Listen to real-time addresses
    _addressesSub = _supabaseService.listenToAddresses(uid).listen(
      (liveAddresses) {
        if (liveAddresses.isNotEmpty) {
          _addresses.clear();
          _addresses.addAll(liveAddresses);
          if (!_addresses.any((a) => a.isSelected)) {
            _addresses[0].isSelected = true;
          }
          _userCurrentLocation = selectedAddress?.addressLine ?? _userCurrentLocation;
          _saveAddressesToLocalCache();
          notifyListeners();
        }
      },
      onError: (e) {
        debugPrint('[Addresses Stream Handled]: $e');
      },
    );

    // Listen to real-time orders (Listen to all if admin, else only user's own)
    if (_userRole == 'admin') {
      _ordersSub = _supabaseService.listenToAllOrders().listen(
        (liveOrders) {
          _orders.clear();
          _orders.addAll(liveOrders);
          _orders.sort((a, b) => b.date.compareTo(a.date));
          notifyListeners();
        },
        onError: (e) {
          debugPrint('[Admin Orders Stream Handled]: $e');
        },
      );
    } else {
      _ordersSub = _supabaseService.listenToOrders(uid).listen(
        (liveOrders) {
          _orders.clear();
          _orders.addAll(liveOrders);
          _orders.sort((a, b) => b.date.compareTo(a.date));
          notifyListeners();
        },
        onError: (e) {
          debugPrint('[Orders Stream Handled]: $e');
        },
      );
    }
  }

  Future<void> logout() async {
    _heartbeatTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_mobile');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('profile_status');
      await prefs.remove('local_cart_cache');
      
      // Clear any cached OTP sessions
      for (final key in prefs.getKeys()) {
        if (key.startsWith('otp_session_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print("Failed to clear login state on logout: $e");
    }
    if (_supabaseService.isSupabaseAvailable) {
      await _supabaseService.client?.auth.signOut();
    }
    _userMobile = null;
    _userName = "User Name";
    _userEmail = "user@example.com";
    _profileStatus = "incomplete";
    _hasClaimedReferralReward = false;
    _cart.clear();
    _currentNavIndex = 0;
    syncUserBackend();
    notifyListeners();
  }

  /// Request permanent deletion of user account and associated personal data
  Future<bool> deleteAccount() async {
    final phone = _userMobile;
    if (phone != null && phone.isNotEmpty) {
      await _supabaseService.deleteUserAccount(phone);
    }
    await logout();
    return true;
  }

  String _userName = "User Name";
  String get userName => _userName;

  String _userEmail = "user@example.com";
  String get userEmail => _userEmail;

  String _profileStatus = "incomplete";
  String get profileStatus => _profileStatus;

  void setLoggedInUser({
    required String mobile,
    required String name,
    required String email,
    required String profileStatus,
  }) async {
    _userMobile = mobile;
    _userName = name;
    _userEmail = email;
    _profileStatus = profileStatus;
    _currentNavIndex = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_mobile', mobile);
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setString('profile_status', profileStatus);
      _hasClaimedReferralReward = prefs.getBool('has_claimed_referral_reward_$mobile') ?? false;
    } catch (e) {
      print("Failed to persist login state: $e");
    }

    syncUserBackend();
    _loadWishlistFromDb(mobile);
    _loadCartFromDb(mobile);
    NotificationService.instance.syncTokenWithSupabase(mobile);
    notifyListeners();
  }

  Future<void> completeProfileAndSync(String name, String email) async {
    _userName = name;
    _userEmail = email;
    _profileStatus = 'complete';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setString('profile_status', 'complete');
    } catch (e) {
      print("Failed to save complete profile locally: $e");
    }

    if (_userMobile != null) {
      await _supabaseService.completeUserProfile(_userMobile!, name, email);
      claimReferralReward();
    }
  }

  void updateProfile(String name, String email) async {
    _userName = name;
    _userEmail = email;
    _profileStatus = 'complete';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setString('profile_status', 'complete');
    } catch (e) {
      print("Failed to persist updated profile: $e");
    }

    if (_userMobile != null) {
      _supabaseService.syncUserProfile(_userMobile!, name, email: email);
    }
  }

  // Mobile number verification state
  String? _userMobile;
  String? get userMobile => _userMobile;

  void setUserMobile(String mobile) async {
    _userMobile = mobile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_mobile', mobile);
    } catch (e) {
      print("Failed to persist login state: $e");
    }
    syncUserBackend();
    notifyListeners();
  }

  void loginUser(String mobile, String name) async {
    _userMobile = mobile;
    _userName = name;
    _userEmail = "user@example.com"; // Reset to default on fresh login
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_mobile', mobile);
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', _userEmail);
    } catch (e) {
      print("Failed to persist login state: $e");
    }
    _supabaseService.syncUserProfile(mobile, name, email: _userEmail);
    syncUserBackend();
    _loadWishlistFromDb(mobile);
    _loadCartFromDb(mobile);
    notifyListeners();
  }

  // Active Bottom Navigation Index
  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }

  // Active category index in CategoryScreen
  int _selectedCategoryIndex = 0;
  int get selectedCategoryIndex => _selectedCategoryIndex;

  String _selectedSubCategoryName = "All";
  String get selectedSubCategoryName => _selectedSubCategoryName;

  bool _isOrganicFilterOnly = false;
  bool get isOrganicFilterOnly => _isOrganicFilterOnly;

  void setIsOrganicFilterOnly(bool value) {
    _isOrganicFilterOnly = value;
    notifyListeners();
  }

  void setSelectedCategoryIndex(int index) {
    _selectedCategoryIndex = index;
    _selectedSubCategoryName = "All";
    _isOrganicFilterOnly = false;
    notifyListeners();
  }

  void setSelectedSubCategoryName(String subCatName) {
    _selectedSubCategoryName = subCatName;
    notifyListeners();
  }

  // Categories Catalog
  final List<CategoryItem> _categories = [
    CategoryItem(id: 'vegetables', name: 'Vegetables', imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Veggies.webp', displayOrder: 1),
    CategoryItem(id: 'fruits', name: 'Fruits', imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Fruits.webp', displayOrder: 2),
    CategoryItem(id: 'dairy', name: 'Dairy', imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Diary.webp', displayOrder: 3),
    CategoryItem(id: 'bakery', name: 'Bakery', imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Bakery.webp', displayOrder: 4),
    CategoryItem(id: 'snacks', name: 'Snacks', imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Snacks.webp', displayOrder: 5),
    CategoryItem(id: 'beverages', name: 'Beverages', imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Beverages.webp', displayOrder: 6),
  ];
  List<CategoryItem> get categories => _categories;

  void setSelectedCategoryByName(String categoryName, {String subCatName = "All", bool organicOnly = false}) {
    final idx = _categories.indexWhere((c) => c.name.toLowerCase() == categoryName.toLowerCase() || c.id.toLowerCase() == categoryName.toLowerCase());
    if (idx != -1) {
      _selectedCategoryIndex = idx;
      _selectedSubCategoryName = subCatName;
      _isOrganicFilterOnly = organicOnly;
      notifyListeners();
    }
  }

  void openCategoryScreen({
    String categoryName = 'Vegetables',
    String subCatName = 'All',
    bool organicOnly = false,
  }) {
    setSelectedCategoryByName(categoryName, subCatName: subCatName, organicOnly: organicOnly);
    setNavIndex(1);
  }

  // Sub-Categories Catalog
  final List<SubCategory> _subCategories = [
    SubCategory(
      id: 'leafy_vegetables',
      categoryId: 'vegetables',
      name: 'Leafy Vegetables',
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Leafy%20Veggies.webp',
    ),
    SubCategory(
      id: 'root_vegetables',
      categoryId: 'vegetables',
      name: 'Root Vegetables',
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Root%20Vegies.webp',
    ),
    SubCategory(
      id: 'organic_vegetables',
      categoryId: 'vegetables',
      name: 'Organic Vegetables',
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Categories/Veggies.webp',
    ),
    SubCategory(
      id: 'fresh_fruits',
      categoryId: 'fruits',
      name: 'Fresh Fruits',
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Fresh%20Fruits.webp',
    ),
    SubCategory(
      id: 'fresh_milk',
      categoryId: 'dairy',
      name: 'Fresh Milk',
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Fresh%20Dairy.webp',
    ),
    SubCategory(
      id: 'cakes',
      categoryId: 'bakery',
      name: 'Cakes',
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Sub%20Categories/Cakes.webp',
    ),
  ];
  List<SubCategory> get subCategories => _subCategories;

  // Product Catalog
  final List<Product> _products = [
    // 1. Vegetables
    Product(
      id: 'veg_bhindi',
      name: 'Bhindi',
      unit: '500g',
      price: 39,
      originalPrice: 45,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Bhindi.webp',
      rating: 4.5,
      ratingCount: 120,
      category: 'Vegetables',
      subCategoryId: 'organic_vegetables',
      description: 'Fresh, tender green ladyfinger rich in fiber, perfect for everyday cooking.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '250g', price: 19, originalPrice: 22),
        ProductVariantOption(unit: '500g', price: 39, originalPrice: 45),
        ProductVariantOption(unit: '1 kg', price: 75, originalPrice: 85),
      ],
    ),
    Product(
      id: 'veg_cabbage',
      name: 'Cabbage',
      unit: '1 pcs',
      price: 39,
      originalPrice: 45,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Cabbage.webp',
      rating: 4.4,
      ratingCount: 95,
      category: 'Vegetables',
      subCategoryId: 'organic_vegetables',
      description: 'Farm-fresh green cabbage with crisp leaves, ideal for salads and curries.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '1 pcs (500g)', price: 20, originalPrice: 25),
        ProductVariantOption(unit: '1 pcs (1 kg)', price: 39, originalPrice: 45),
        ProductVariantOption(unit: '1 pcs (1.5 kg)', price: 55, originalPrice: 65),
      ],
    ),
    Product(
      id: 'veg_capsicum',
      name: 'Capsicum',
      unit: '500g',
      price: 59,
      originalPrice: 70,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Capsicum.webp',
      rating: 4.5,
      ratingCount: 110,
      category: 'Vegetables',
      subCategoryId: 'organic_vegetables',
      description: 'Fresh green capsicum with a crunchy texture, suitable for Chinese and Indian dishes.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '250g', price: 32, originalPrice: 38),
        ProductVariantOption(unit: '500g', price: 59, originalPrice: 70),
        ProductVariantOption(unit: '1 kg', price: 110, originalPrice: 130),
      ],
    ),
    Product(
      id: 'veg_carrot',
      name: 'Carrot',
      unit: '500g',
      price: 39,
      originalPrice: 45,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Carrot.webp',
      rating: 4.4,
      ratingCount: 120,
      category: 'Vegetables',
      subCategoryId: 'root_vegetables',
      description: 'Fresh organic carrots, sweet and crisp, perfect for salads and juice.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250g', price: 20, originalPrice: 25),
        ProductVariantOption(unit: '500g', price: 39, originalPrice: 45),
        ProductVariantOption(unit: '1 kg', price: 75, originalPrice: 85),
      ],
    ),
    Product(
      id: 'veg_cauliflower',
      name: 'Cauliflower',
      unit: '1 pcs',
      price: 55,
      originalPrice: 65,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Cauliflower.webp',
      rating: 4.4,
      ratingCount: 140,
      category: 'Vegetables',
      subCategoryId: 'organic_vegetables',
      description: 'Fresh white cauliflower with tightly packed florets, perfect for curries and snacks.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '1 pcs (400g)', price: 28, originalPrice: 35),
        ProductVariantOption(unit: '1 pcs (800g)', price: 55, originalPrice: 65),
        ProductVariantOption(unit: '1 pcs (1.2 kg)', price: 79, originalPrice: 90),
      ],
    ),
    Product(
      id: 'veg_chili',
      name: 'Chili',
      unit: '100g',
      price: 15,
      originalPrice: 20,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Chili.webp',
      rating: 4.6,
      ratingCount: 180,
      category: 'Vegetables',
      description: 'Fresh green chilies with natural spicy flavor for enhancing every meal.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '100g', price: 15, originalPrice: 20),
        ProductVariantOption(unit: '250g', price: 32, originalPrice: 40),
        ProductVariantOption(unit: '500g', price: 59, originalPrice: 70),
      ],
    ),
    Product(
      id: 'veg_cucumber',
      name: 'Cucumber',
      unit: '500g',
      price: 29,
      originalPrice: 35,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Cucumber.webp',
      rating: 4.3,
      ratingCount: 135,
      category: 'Vegetables',
      subCategoryId: 'organic_vegetables',
      description: 'Fresh, juicy cucumber rich in water content, great for salads and healthy diets.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '250g', price: 15, originalPrice: 18),
        ProductVariantOption(unit: '500g', price: 29, originalPrice: 35),
        ProductVariantOption(unit: '1 kg', price: 55, originalPrice: 65),
      ],
    ),
    Product(
      id: 'veg_mutter',
      name: 'Mutter (Green Peas)',
      unit: '500g',
      price: 79,
      originalPrice: 90,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Mutter.webp',
      rating: 4.5,
      ratingCount: 150,
      category: 'Vegetables',
      description: 'Fresh green peas packed with protein and natural sweetness.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250g', price: 42, originalPrice: 50),
        ProductVariantOption(unit: '500g', price: 79, originalPrice: 90),
        ProductVariantOption(unit: '1 kg', price: 149, originalPrice: 170),
      ],
    ),
    Product(
      id: 'veg_onion',
      name: 'Onion',
      unit: '1 kg',
      price: 39,
      originalPrice: 45,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Onion.webp',
      rating: 4.6,
      ratingCount: 310,
      category: 'Vegetables',
      subCategoryId: 'root_vegetables',
      description: 'Premium quality red onions with a strong natural flavor for daily cooking.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '1 kg', price: 39, originalPrice: 45),
        ProductVariantOption(unit: '2 kg', price: 75, originalPrice: 85),
        ProductVariantOption(unit: '5 kg', price: 179, originalPrice: 200),
      ],
    ),
    Product(
      id: 'veg_potato',
      name: 'Potato',
      unit: '1 kg',
      price: 35,
      originalPrice: 40,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Potato.webp',
      rating: 4.5,
      ratingCount: 410,
      category: 'Vegetables',
      subCategoryId: 'organic_vegetables',
      description: 'Fresh farm potatoes suitable for fries, curries, and everyday meals.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '1 kg', price: 35, originalPrice: 40),
        ProductVariantOption(unit: '2 kg', price: 65, originalPrice: 75),
        ProductVariantOption(unit: '5 kg', price: 155, originalPrice: 180),
      ],
    ),
    Product(
      id: 'veg_radish',
      name: 'Radish',
      unit: '500g',
      price: 29,
      originalPrice: 35,
      imageUrl: 'https://images.unsplash.com/photo-1590004953392-5aba2e72269a?w=500&auto=format&fit=crop&q=60',
      rating: 4.2,
      ratingCount: 65,
      category: 'Vegetables',
      description: 'Fresh white radish with a crunchy texture, perfect for salads and parathas.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250g', price: 15, originalPrice: 20),
        ProductVariantOption(unit: '500g', price: 29, originalPrice: 35),
        ProductVariantOption(unit: '1 kg', price: 55, originalPrice: 65),
      ],
    ),
    Product(
      id: 'veg_saag',
      name: 'Saag (Mustard Greens)',
      unit: '500g',
      price: 35,
      originalPrice: 40,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Saag.webp',
      rating: 4.4,
      ratingCount: 80,
      category: 'Vegetables',
      subCategoryId: 'leafy_vegetables',
      description: 'Fresh mustard greens rich in iron and vitamins, ideal for traditional dishes.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250g', price: 18, originalPrice: 22),
        ProductVariantOption(unit: '500g', price: 35, originalPrice: 40),
        ProductVariantOption(unit: '1 kg', price: 65, originalPrice: 75),
      ],
    ),
    Product(
      id: 'veg_sem',
      name: 'Sem (French Beans)',
      unit: '500g',
      price: 59,
      originalPrice: 70,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Beans.webp',
      rating: 4.3,
      ratingCount: 55,
      category: 'Vegetables',
      description: 'Fresh green beans with a tender texture, perfect for stir-fries and curries.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250g', price: 32, originalPrice: 38),
        ProductVariantOption(unit: '500g', price: 59, originalPrice: 70),
        ProductVariantOption(unit: '1 kg', price: 110, originalPrice: 130),
      ],
    ),
    Product(
      id: 'veg_spinach',
      name: 'Spinach',
      unit: '500g',
      price: 35,
      originalPrice: 40,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Spinach.webp',
      rating: 4.5,
      ratingCount: 190,
      category: 'Vegetables',
      subCategoryId: 'organic_vegetables',
      description: 'Fresh spinach leaves rich in iron and nutrients, ideal for healthy recipes.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '250g', price: 18, originalPrice: 22),
        ProductVariantOption(unit: '500g', price: 35, originalPrice: 40),
        ProductVariantOption(unit: '1 kg', price: 65, originalPrice: 75),
      ],
    ),
    Product(
      id: 'veg_tomato',
      name: 'Tomato',
      unit: '1 kg',
      price: 49,
      originalPrice: 60,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Vegetables/Tomato.webp',
      rating: 4.6,
      ratingCount: 380,
      category: 'Vegetables',
      subCategoryId: 'organic_vegetables',
      description: 'Fresh, juicy red tomatoes with a rich natural taste for everyday cooking.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '500g', price: 26, originalPrice: 32),
        ProductVariantOption(unit: '1 kg', price: 49, originalPrice: 60),
        ProductVariantOption(unit: '2 kg', price: 92, originalPrice: 110),
      ],
    ),

    // 2. Fruits
    Product(
      id: 'fr_apple',
      name: 'Apple',
      unit: '1 kg',
      price: 199,
      originalPrice: 220,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Apple.webp',
      rating: 4.7,
      ratingCount: 340,
      category: 'Fruits',
      subCategoryId: 'fresh_fruits',
      description: 'Fresh premium red apples.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '500g', price: 105, originalPrice: 115),
        ProductVariantOption(unit: '1 kg', price: 199, originalPrice: 220),
        ProductVariantOption(unit: '2 kg', price: 380, originalPrice: 420),
      ],
    ),
    Product(
      id: 'fr_banana',
      name: 'Banana',
      unit: '1 dozen',
      price: 59,
      originalPrice: 70,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Banana.webp',
      rating: 4.5,
      ratingCount: 512,
      category: 'Fruits',
      description: 'Fresh ripe yellow bananas.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '6 pcs', price: 32, originalPrice: 38),
        ProductVariantOption(unit: '1 dozen', price: 59, originalPrice: 70),
        ProductVariantOption(unit: '2 dozen', price: 110, originalPrice: 130),
      ],
    ),
    Product(
      id: 'fr_grapes',
      name: 'Grapes',
      unit: '500g',
      price: 79,
      originalPrice: 90,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Grapes.webp',
      rating: 4.4,
      ratingCount: 198,
      category: 'Fruits',
      subCategoryId: 'fresh_fruits',
      description: 'Fresh seedless green grapes.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '250g', price: 42, originalPrice: 48),
        ProductVariantOption(unit: '500g', price: 79, originalPrice: 90),
        ProductVariantOption(unit: '1 kg', price: 150, originalPrice: 170),
      ],
    ),
    Product(
      id: 'fr_guava',
      name: 'Guava',
      unit: '1 kg',
      price: 79,
      originalPrice: 90,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Guava.webp',
      rating: 4.3,
      ratingCount: 88,
      category: 'Fruits',
      description: 'Fresh green guava rich in Vitamin C.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '500g', price: 42, originalPrice: 48),
        ProductVariantOption(unit: '1 kg', price: 79, originalPrice: 90),
        ProductVariantOption(unit: '2 kg', price: 150, originalPrice: 170),
      ],
    ),
    Product(
      id: 'fr_kashmiri_guava',
      name: 'Kashmiri Guava',
      unit: '1 kg',
      price: 129,
      originalPrice: 140,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Kashmiri%20Guava.webp',
      rating: 4.5,
      ratingCount: 64,
      category: 'Fruits',
      description: 'Premium sweet Kashmiri guava.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '500g', price: 69, originalPrice: 75),
        ProductVariantOption(unit: '1 kg', price: 129, originalPrice: 140),
        ProductVariantOption(unit: '2 kg', price: 249, originalPrice: 270),
      ],
    ),
    Product(
      id: 'fr_kiwi',
      name: 'Kiwi',
      unit: '3 pcs',
      price: 139,
      originalPrice: 150,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Kiwi.webp',
      rating: 4.4,
      ratingCount: 95,
      category: 'Fruits',
      description: 'Imported fresh kiwi fruit.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '3 pcs', price: 139, originalPrice: 150),
        ProductVariantOption(unit: '6 pcs', price: 269, originalPrice: 290),
        ProductVariantOption(unit: '12 pcs', price: 519, originalPrice: 550),
      ],
    ),
    Product(
      id: 'fr_mango',
      name: 'Mango',
      unit: '1 kg',
      price: 99,
      originalPrice: 120,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Mango.webp',
      rating: 4.8,
      ratingCount: 650,
      category: 'Fruits',
      subCategoryId: 'fresh_fruits',
      description: 'Sweet juicy seasonal mangoes.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '500g', price: 55, originalPrice: 65),
        ProductVariantOption(unit: '1 kg', price: 99, originalPrice: 120),
        ProductVariantOption(unit: '2 kg', price: 189, originalPrice: 230),
      ],
    ),
    Product(
      id: 'fr_orange',
      name: 'Orange',
      unit: '1 kg',
      price: 89,
      originalPrice: 100,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Orange.webp',
      rating: 4.5,
      ratingCount: 220,
      category: 'Fruits',
      description: 'Fresh juicy oranges.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '500g', price: 48, originalPrice: 55),
        ProductVariantOption(unit: '1 kg', price: 89, originalPrice: 100),
        ProductVariantOption(unit: '2 kg', price: 169, originalPrice: 190),
      ],
    ),
    Product(
      id: 'fr_papaya',
      name: 'Papaya',
      unit: '1 kg',
      price: 59,
      originalPrice: 70,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Papaya.webp',
      rating: 4.3,
      ratingCount: 112,
      category: 'Fruits',
      description: 'Naturally ripe fresh papaya.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '1 pcs (approx 800g)', price: 49, originalPrice: 58),
        ProductVariantOption(unit: '1 pcs (approx 1.5kg)', price: 89, originalPrice: 100),
        ProductVariantOption(unit: '1 pcs (approx 2.2kg)', price: 129, originalPrice: 140),
      ],
    ),
    Product(
      id: 'fr_pear',
      name: 'Pear',
      unit: '1 kg',
      price: 199,
      originalPrice: 220,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Papaya.webp',
      rating: 4.4,
      ratingCount: 75,
      category: 'Fruits',
      description: 'Fresh crunchy pears.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '500g', price: 105, originalPrice: 115),
        ProductVariantOption(unit: '1 kg', price: 199, originalPrice: 220),
        ProductVariantOption(unit: '2 kg', price: 380, originalPrice: 420),
      ],
    ),
    Product(
      id: 'fr_pineapple',
      name: 'Pineapple',
      unit: '1 pcs',
      price: 79,
      originalPrice: 90,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Pineapple.webp',
      rating: 4.6,
      ratingCount: 140,
      category: 'Fruits',
      subCategoryId: 'fresh_fruits',
      description: 'Sweet tropical pineapple.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '1 pcs (Small)', price: 49, originalPrice: 55),
        ProductVariantOption(unit: '1 pcs (Medium)', price: 79, originalPrice: 90),
        ProductVariantOption(unit: '1 pcs (Large)', price: 109, originalPrice: 120),
      ],
    ),
    Product(
      id: 'fr_pomegranate',
      name: 'Pomegranate',
      unit: '1 kg',
      price: 199,
      originalPrice: 220,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Pomegranate.webp',
      rating: 4.6,
      ratingCount: 145,
      category: 'Fruits',
      description: 'Fresh ruby red pomegranate.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '500g', price: 105, originalPrice: 115),
        ProductVariantOption(unit: '1 kg', price: 199, originalPrice: 220),
        ProductVariantOption(unit: '2 kg', price: 380, originalPrice: 420),
      ],
    ),
    Product(
      id: 'fr_watermelon',
      name: 'Watermelon',
      unit: '1 pcs',
      price: 99,
      originalPrice: 110,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Fruits/Watermelon.webp',
      rating: 4.5,
      ratingCount: 300,
      category: 'Fruits',
      description: 'Fresh juicy watermelon.',
      isOrganic: true,
      variants: [
        ProductVariantOption(unit: '1 pcs (approx 2kg)', price: 49, originalPrice: 55),
        ProductVariantOption(unit: '1 pcs (approx 4kg)', price: 99, originalPrice: 110),
        ProductVariantOption(unit: '1 pcs (approx 6kg)', price: 139, originalPrice: 150),
      ],
    ),

    // 3. Dairy
    Product(
      id: 'dy_amulya_milk_powder',
      name: 'Amulya Milk Powder',
      unit: '500g',
      price: 245,
      originalPrice: 255,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Amulya.webp',
      rating: 4.6,
      ratingCount: 150,
      category: 'Dairy',
      description: 'Premium dairy whitener made from high-quality milk, perfect for tea, coffee, and desserts.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '200g', price: 105, originalPrice: 110),
        ProductVariantOption(unit: '500g', price: 245, originalPrice: 255),
        ProductVariantOption(unit: '1 kg', price: 479, originalPrice: 499),
      ],
    ),
    Product(
      id: 'dy_butter',
      name: 'Butter',
      unit: '500g',
      price: 299,
      originalPrice: 310,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Butter.webp',
      rating: 4.8,
      ratingCount: 920,
      category: 'Dairy',
      description: 'Fresh and creamy salted butter made from pure milk, ideal for cooking, baking, and spreading.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '100g', price: 62, originalPrice: 65),
        ProductVariantOption(unit: '500g', price: 299, originalPrice: 310),
        ProductVariantOption(unit: '1 kg', price: 585, originalPrice: 600),
      ],
    ),
    Product(
      id: 'dy_buttermilk',
      name: 'Buttermilk',
      unit: '500ml',
      price: 27,
      originalPrice: 29,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/ButterMilk.webp',
      rating: 4.5,
      ratingCount: 310,
      category: 'Dairy',
      description: 'Refreshing probiotic buttermilk prepared from fresh curd, perfect for daily digestion and hydration.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '200ml', price: 12, originalPrice: 13),
        ProductVariantOption(unit: '500ml', price: 27, originalPrice: 29),
        ProductVariantOption(unit: '1L', price: 52, originalPrice: 55),
      ],
    ),
    Product(
      id: 'dy_cheese',
      name: 'Cheese',
      unit: '200g',
      price: 129,
      originalPrice: 135,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Cheese.webp',
      rating: 4.4,
      ratingCount: 180,
      category: 'Dairy',
      description: 'Rich and creamy processed cheese made from premium milk, suitable for sandwiches, pizzas, and snacks.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '100g', price: 68, originalPrice: 72),
        ProductVariantOption(unit: '200g', price: 129, originalPrice: 135),
        ProductVariantOption(unit: '400g', price: 249, originalPrice: 260),
      ],
    ),
    Product(
      id: 'dy_fresh_cream',
      name: 'Fresh Cream',
      unit: '250ml',
      price: 70,
      originalPrice: 75,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Cream.webp',
      rating: 4.6,
      ratingCount: 140,
      category: 'Dairy',
      description: 'Smooth and rich fresh cream for cooking, baking, soups, desserts, and gravies.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250ml', price: 70, originalPrice: 75),
        ProductVariantOption(unit: '1L', price: 259, originalPrice: 275),
        ProductVariantOption(unit: '2L', price: 499, originalPrice: 530),
      ],
    ),
    Product(
      id: 'dy_curd',
      name: 'Curd',
      unit: '900g',
      price: 49,
      originalPrice: 52,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Curd.webp',
      rating: 4.5,
      ratingCount: 260,
      category: 'Dairy',
      description: 'Thick and creamy fresh curd prepared from high-quality pasteurized milk.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '200g', price: 18, originalPrice: 20),
        ProductVariantOption(unit: '400g', price: 34, originalPrice: 36),
        ProductVariantOption(unit: '900g', price: 49, originalPrice: 52),
      ],
    ),
    Product(
      id: 'dy_dahi',
      name: 'Dahi',
      unit: '450g',
      price: 34,
      originalPrice: 36,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Dahi.webp',
      rating: 4.4,
      ratingCount: 110,
      category: 'Dairy',
      subCategoryId: 'fresh_milk',
      description: 'Fresh homemade-style dahi with a rich texture and natural taste, ideal for daily meals.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '200g', price: 18, originalPrice: 20),
        ProductVariantOption(unit: '450g', price: 34, originalPrice: 36),
        ProductVariantOption(unit: '1 kg', price: 72, originalPrice: 75),
      ],
    ),
    Product(
      id: 'dy_ghee',
      name: 'Ghee',
      unit: '1 liter',
      price: 679,
      originalPrice: 710,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Ghee.webp',
      rating: 4.8,
      ratingCount: 880,
      category: 'Dairy',
      description: 'Pure cow ghee with authentic aroma and rich taste, suitable for cooking and religious use.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '200ml', price: 155, originalPrice: 165),
        ProductVariantOption(unit: '500ml', price: 350, originalPrice: 365),
        ProductVariantOption(unit: '1 liter', price: 679, originalPrice: 710),
      ],
    ),
    Product(
      id: 'dy_ice_cream',
      name: 'Ice Cream',
      unit: '750ml',
      price: 149,
      originalPrice: 162,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Ice%20Cream.webp',
      rating: 4.6,
      ratingCount: 300,
      category: 'Dairy',
      description: 'Delicious creamy vanilla ice cream made with premium dairy ingredients for a rich taste.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '100ml', price: 25, originalPrice: 28),
        ProductVariantOption(unit: '500ml', price: 110, originalPrice: 120),
        ProductVariantOption(unit: '750ml', price: 149, originalPrice: 162),
      ],
    ),
    Product(
      id: 'dy_malai',
      name: 'Malai',
      unit: '250g',
      price: 89,
      originalPrice: 95,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Malai.webp',
      rating: 4.5,
      ratingCount: 95,
      category: 'Dairy',
      description: 'Fresh milk malai with a rich creamy texture, ideal for sweets, curries, and desserts.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '100g', price: 39, originalPrice: 42),
        ProductVariantOption(unit: '250g', price: 89, originalPrice: 95),
        ProductVariantOption(unit: '500g', price: 169, originalPrice: 180),
      ],
    ),
    Product(
      id: 'dy_milk',
      name: 'Milk',
      unit: '1 liter',
      price: 68,
      originalPrice: 70,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Milk.webp',
      rating: 4.6,
      ratingCount: 880,
      category: 'Dairy',
      subCategoryId: 'fresh_milk',
      description: 'Fresh pasteurized toned milk rich in calcium and protein for everyday nutrition.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '500ml', price: 34, originalPrice: 35),
        ProductVariantOption(unit: '1 liter', price: 68, originalPrice: 70),
        ProductVariantOption(unit: '2 liter', price: 132, originalPrice: 136),
      ],
    ),
    Product(
      id: 'dy_paneer',
      name: 'Paneer',
      unit: '200g',
      price: 79,
      originalPrice: 85,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Dairy/Paneer.webp',
      rating: 4.7,
      ratingCount: 450,
      category: 'Dairy',
      subCategoryId: 'fresh_milk',
      description: 'Soft and fresh cottage cheese made from pure milk, perfect for Indian and continental dishes.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '100g', price: 42, originalPrice: 45),
        ProductVariantOption(unit: '200g', price: 79, originalPrice: 85),
        ProductVariantOption(unit: '500g', price: 189, originalPrice: 200),
      ],
    ),

    // 4. Bakery
    Product(
      id: 'bk_bread',
      name: 'Bread',
      unit: '400g',
      price: 45,
      originalPrice: 50,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Bakery/Bread.webp',
      rating: 4.5,
      ratingCount: 120,
      category: 'Bakery',
      description: 'Freshly baked soft sandwich bread made from premium wheat flour, perfect for breakfast and snacks.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '200g', price: 27, originalPrice: 30),
        ProductVariantOption(unit: '400g', price: 45, originalPrice: 50),
        ProductVariantOption(unit: '800g', price: 89, originalPrice: 95),
      ],
    ),
    Product(
      id: 'bk_chocolate_cake',
      name: 'Chocolate Cake',
      unit: '500g',
      price: 499,
      originalPrice: 550,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Bakery/Cocoalate%20Cake.webp',
      rating: 4.7,
      ratingCount: 160,
      category: 'Bakery',
      subCategoryId: 'cakes',
      description: 'Rich chocolate sponge cake layered with creamy chocolate frosting, ideal for birthdays and celebrations.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '500g', price: 499, originalPrice: 550),
        ProductVariantOption(unit: '1 kg', price: 899, originalPrice: 1000),
        ProductVariantOption(unit: '2 kg', price: 1799, originalPrice: 1950),
      ],
    ),
    Product(
      id: 'bk_fruit_cake',
      name: 'Fruit Cake',
      unit: '500g',
      price: 549,
      originalPrice: 600,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Bakery/Fruit%20Cake.webp',
      rating: 4.6,
      ratingCount: 140,
      category: 'Bakery',
      subCategoryId: 'cakes',
      description: 'Soft vanilla sponge cake topped with fresh seasonal fruits and whipped cream.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '500g', price: 549, originalPrice: 600),
        ProductVariantOption(unit: '1 kg', price: 999, originalPrice: 1100),
        ProductVariantOption(unit: '2 kg', price: 1949, originalPrice: 2100),
      ],
    ),
    Product(
      id: 'bk_multi_layer_cake',
      name: 'Anniversary Cake',
      unit: '1 kg',
      price: 999,
      originalPrice: 1100,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Bakery/MCake.webp',
      rating: 4.8,
      ratingCount: 85,
      category: 'Bakery',
      subCategoryId: 'cakes',
      description: 'Premium multi-layer celebration cake with delicious cream filling and decorative frosting.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '1 kg', price: 999, originalPrice: 1100),
        ProductVariantOption(unit: '2 kg', price: 1949, originalPrice: 2100),
        ProductVariantOption(unit: '3 kg', price: 2899, originalPrice: 3100),
      ],
    ),
    Product(
      id: 'bk_pav_buns',
      name: 'Pav Buns',
      unit: '6 pcs',
      price: 40,
      originalPrice: 45,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Bakery/Paav%20Buns.webp',
      rating: 4.3,
      ratingCount: 98,
      category: 'Bakery',
      description: 'Soft and fluffy pav buns freshly baked, perfect for pav bhaji, burgers, and sandwiches.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '4 pcs', price: 27, originalPrice: 30),
        ProductVariantOption(unit: '6 pcs', price: 40, originalPrice: 45),
        ProductVariantOption(unit: '12 pcs', price: 79, originalPrice: 85),
      ],
    ),
    Product(
      id: 'bk_pizza',
      name: 'Pizza',
      unit: '1 pcs',
      price: 299,
      originalPrice: 349,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Bakery/Pizza.webp',
      rating: 4.6,
      ratingCount: 220,
      category: 'Bakery',
      description: 'Freshly baked vegetable cheese pizza loaded with mozzarella cheese and flavorful toppings.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '1 pcs (Regular)', price: 299, originalPrice: 349),
        ProductVariantOption(unit: '1 pcs (Medium)', price: 499, originalPrice: 549),
        ProductVariantOption(unit: '1 pcs (Large)', price: 749, originalPrice: 799),
      ],
    ),

    // 6. Snacks
    Product(
      id: 'sn_aloo_bhujiya',
      name: 'Aloo Bhujiya',
      unit: '400g',
      price: 159,
      originalPrice: 170,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Snacks/Aloo%20Bhujiya.webp',
      rating: 4.4,
      ratingCount: 880,
      category: 'Snacks',
      description: 'Crispy and spicy potato-based namkeen made with gram flour, perfect for tea-time and everyday snacking.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '150g', price: 55, originalPrice: 60),
        ProductVariantOption(unit: '400g', price: 159, originalPrice: 170),
        ProductVariantOption(unit: '1 kg', price: 369, originalPrice: 390),
      ],
    ),
    Product(
      id: 'sn_aloo_bhujiya_premium',
      name: 'Aloo Bhujiyaa (Premium)',
      unit: '1 kg',
      price: 399,
      originalPrice: 420,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Snacks/Aloo%20Bhujiya.webp',
      rating: 4.6,
      ratingCount: 150,
      category: 'Snacks',
      description: 'Premium crunchy aloo bhujia prepared with authentic spices for a rich traditional taste.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '150g', price: 65, originalPrice: 70),
        ProductVariantOption(unit: '400g', price: 179, originalPrice: 190),
        ProductVariantOption(unit: '1 kg', price: 399, originalPrice: 420),
      ],
    ),
    Product(
      id: 'sn_biscuit',
      name: 'Biscuit',
      unit: '300g',
      price: 50,
      originalPrice: 55,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Snacks/Biscuit.webp',
      rating: 4.3,
      ratingCount: 420,
      category: 'Snacks',
      description: 'Crispy and delicious tea-time biscuits baked with premium quality ingredients.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '100g', price: 18, originalPrice: 20),
        ProductVariantOption(unit: '300g', price: 50, originalPrice: 55),
        ProductVariantOption(unit: '600g', price: 95, originalPrice: 105),
      ],
    ),
    Product(
      id: 'sn_butter_makkhan_roti',
      name: 'Butter Makkhan Roti',
      unit: '6 pcs',
      price: 69,
      originalPrice: 75,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Snacks/Butter%20Makkhan%20Roti.webp',
      rating: 4.5,
      ratingCount: 95,
      category: 'Snacks',
      description: 'Soft butter-flavoured baked roti, ready to heat and enjoy with curries or tea.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '3 pcs', price: 36, originalPrice: 40),
        ProductVariantOption(unit: '6 pcs', price: 69, originalPrice: 75),
        ProductVariantOption(unit: '12 pcs', price: 129, originalPrice: 140),
      ],
    ),
    Product(
      id: 'sn_kurkure',
      name: 'Kurkure',
      unit: '90g',
      price: 20,
      originalPrice: 25,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Snacks/Kurkure.webp',
      rating: 4.4,
      ratingCount: 230,
      category: 'Snacks',
      description: 'Crunchy masala corn puffs packed with bold Indian spices for a delicious snack.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '40g', price: 10, originalPrice: 10),
        ProductVariantOption(unit: '90g', price: 20, originalPrice: 25),
        ProductVariantOption(unit: '150g', price: 33, originalPrice: 35),
      ],
    ),
    Product(
      id: 'sn_lays_classic_chips',
      name: 'Lay\'s Classic Chips',
      unit: '82g',
      price: 45,
      originalPrice: 50,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Snacks/Lays.webp',
      rating: 4.2,
      ratingCount: 1200,
      category: 'Snacks',
      description: 'Thin, crispy potato chips lightly salted for a classic crunchy snacking experience.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '30g', price: 10, originalPrice: 10),
        ProductVariantOption(unit: '50g', price: 20, originalPrice: 20),
        ProductVariantOption(unit: '82g', price: 45, originalPrice: 50),
      ],
    ),

    // 7. Beverages
    Product(
      id: 'bv_cold_coffee',
      name: 'Cold Coffee',
      unit: '250 ml',
      price: 55,
      originalPrice: 60,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Beverage/Cold%20Coffee.webp',
      rating: 4.5,
      ratingCount: 310,
      category: 'Beverages',
      description: 'Rich and creamy ready-to-drink cold coffee made with premium milk and coffee beans.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '180 ml', price: 38, originalPrice: 40),
        ProductVariantOption(unit: '250 ml', price: 55, originalPrice: 60),
        ProductVariantOption(unit: '300 ml', price: 69, originalPrice: 75),
      ],
    ),
    Product(
      id: 'bv_lahori_zeera',
      name: 'Lahori Zeera',
      unit: '600 ml',
      price: 40,
      originalPrice: 45,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Beverage/Lahori%20Zeera.webp',
      rating: 4.4,
      ratingCount: 190,
      category: 'Beverages',
      description: 'Refreshing jeera-flavored carbonated drink with authentic Indian spices.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250 ml', price: 18, originalPrice: 20),
        ProductVariantOption(unit: '600 ml', price: 40, originalPrice: 45),
        ProductVariantOption(unit: '1.25 liter', price: 69, originalPrice: 75),
      ],
    ),
    Product(
      id: 'bv_lassi',
      name: 'Lassi',
      unit: '200 ml',
      price: 28,
      originalPrice: 30,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Beverage/Lassi.webp',
      rating: 4.6,
      ratingCount: 420,
      category: 'Beverages',
      description: 'Traditional sweet yogurt drink made from fresh curd, perfect for a refreshing treat.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '200 ml', price: 28, originalPrice: 30),
        ProductVariantOption(unit: '500 ml', price: 55, originalPrice: 60),
        ProductVariantOption(unit: '1 liter', price: 99, originalPrice: 110),
      ],
    ),
    Product(
      id: 'bv_maaza',
      name: 'Maaza',
      unit: '600 ml',
      price: 40,
      originalPrice: 45,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Beverage/Maaza.webp',
      rating: 4.5,
      ratingCount: 500,
      category: 'Beverages',
      description: 'Delicious mango fruit drink made with real mango pulp for a refreshing taste.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250 ml', price: 18, originalPrice: 20),
        ProductVariantOption(unit: '600 ml', price: 40, originalPrice: 45),
        ProductVariantOption(unit: '1.2 liter', price: 69, originalPrice: 75),
      ],
    ),
    Product(
      id: 'bv_mineral_drinking_water',
      name: 'Mineral Drinking Water',
      unit: '1 liter',
      price: 20,
      originalPrice: 20,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Beverage/Mineral%20Drinking%20Water.webp',
      rating: 4.7,
      ratingCount: 880,
      category: 'Beverages',
      description: 'Packaged drinking water purified through advanced filtration for safe daily hydration.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '500 ml', price: 10, originalPrice: 10),
        ProductVariantOption(unit: '1 liter', price: 20, originalPrice: 20),
        ProductVariantOption(unit: '2 liter', price: 28, originalPrice: 30),
      ],
    ),
    Product(
      id: 'bv_soda_water',
      name: 'Soda Water',
      unit: '750 ml',
      price: 22,
      originalPrice: 25,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Beverage/Soda%20Water.webp',
      rating: 4.3,
      ratingCount: 120,
      category: 'Beverages',
      description: 'Crisp carbonated soda water, ideal for refreshing drinks and mocktails.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '300 ml', price: 14, originalPrice: 15),
        ProductVariantOption(unit: '750 ml', price: 22, originalPrice: 25),
        ProductVariantOption(unit: '1 liter', price: 32, originalPrice: 35),
      ],
    ),
    Product(
      id: 'bv_sprite',
      name: 'Sprite',
      unit: '750 ml',
      price: 38,
      originalPrice: 40,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Beverage/Sprite.webp',
      rating: 4.5,
      ratingCount: 990,
      category: 'Beverages',
      description: 'Lemon-lime flavored soft drink with a refreshing and fizzy taste.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250 ml', price: 18, originalPrice: 20),
        ProductVariantOption(unit: '750 ml', price: 38, originalPrice: 40),
        ProductVariantOption(unit: '2.25 liter', price: 95, originalPrice: 99),
      ],
    ),
    Product(
      id: 'bv_sting_energy_drink',
      name: 'Sting Energy Drink',
      unit: '250 ml',
      price: 22,
      originalPrice: 25,
      imageUrl: 'https://mhqyaqvnlurqamojelae.supabase.co/storage/v1/object/public/SabzeeWala/Products/Beverage/Sting%20Drink.webp',
      rating: 4.4,
      ratingCount: 350,
      category: 'Beverages',
      description: 'High-energy carbonated drink with caffeine and vitamins for an instant energy boost.',
      isOrganic: false,
      variants: [
        ProductVariantOption(unit: '250 ml', price: 22, originalPrice: 25),
        ProductVariantOption(unit: '350 ml', price: 32, originalPrice: 35),
        ProductVariantOption(unit: '500 ml', price: 50, originalPrice: 55),
      ],
    ),

  ];

  List<Product> get products => _products;

  List<Product> getProductsByCategory(String category) {
    if (category == 'All') return _products;
    return _products.where((p) => p.category == category).toList();
  }

  Product? findProductById(String id) {
    if (id.isEmpty) return null;
    try {
      return _products.firstWhere(
        (p) => p.id == id || (p.productId.isNotEmpty && p.productId == id),
      );
    } catch (_) {
      return null;
    }
  }

  // Active Cart State
  final Map<String, CartItem> _cart = {};

  void _syncCartPricesSilently() {
    if (_cart.isEmpty || _products.isEmpty) return;
    for (final key in _cart.keys.toList()) {
      final item = _cart[key];
      if (item == null) continue;
      final liveProduct = findProductById(item.product.id) ??
          (item.product.productId.isNotEmpty ? findProductById(item.product.productId) : null);
      if (liveProduct != null) {
        final prices = getProductPriceForUnit(liveProduct, item.selectedUnit);
        final double newPrice = prices['price'] ?? liveProduct.price;
        final double newOriginalPrice = prices['originalPrice'] ?? liveProduct.originalPrice;
        if ((item.price - newPrice).abs() > 0.001 ||
            (item.originalPrice - newOriginalPrice).abs() > 0.001 ||
            !identical(item.product, liveProduct)) {
          _cart[key] = item.copyWith(
            product: liveProduct,
            price: newPrice,
            originalPrice: newOriginalPrice,
          );
        }
      }
    }
  }

  bool syncCartWithCatalog({bool notify = true}) {
    if (_cart.isEmpty || _products.isEmpty) return false;
    bool changed = false;
    for (final key in _cart.keys.toList()) {
      final item = _cart[key];
      if (item == null) continue;
      final liveProduct = findProductById(item.product.id) ??
          (item.product.productId.isNotEmpty ? findProductById(item.product.productId) : null);
      if (liveProduct != null) {
        final prices = getProductPriceForUnit(liveProduct, item.selectedUnit);
        final double newPrice = prices['price'] ?? liveProduct.price;
        final double newOriginalPrice = prices['originalPrice'] ?? liveProduct.originalPrice;
        if ((item.price - newPrice).abs() > 0.001 ||
            (item.originalPrice - newOriginalPrice).abs() > 0.001 ||
            !identical(item.product, liveProduct)) {
          _cart[key] = item.copyWith(
            product: liveProduct,
            price: newPrice,
            originalPrice: newOriginalPrice,
          );
          changed = true;
        }
      }
    }
    if (changed) {
      _persistCartLocally();
      if (notify) {
        notifyListeners();
      }
    }
    return changed;
  }

  Map<String, CartItem> get cart {
    _syncCartPricesSilently();
    return _cart;
  }

  List<CartItem> get cartItems {
    _syncCartPricesSilently();
    return _cart.values.toList();
  }

  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get cartSubtotal {
    _syncCartPricesSilently();
    return _cart.values.fold(0.0, (sum, item) => sum + item.totalProductPrice);
  }

  double get cartSubtotalOriginal {
    _syncCartPricesSilently();
    return _cart.values.fold(0.0, (sum, item) => sum + (item.originalPrice * item.quantity));
  }

  double get mrpDiscount => (cartSubtotalOriginal - cartSubtotal).clamp(0.0, double.infinity);

  bool _isStorePickup = false;
  bool get isStorePickup => _isStorePickup;

  void setStorePickup(bool value) {
    _isStorePickup = value;
    notifyListeners();
  }

  // Active Coupon Code
  String? _appliedCouponCode;
  bool _couponRemovedManually = false;

  String? get appliedCouponCode {
    if (_couponRemovedManually) {
      return null;
    }
    if (_appliedCouponCode != null) {
      // Check if it is still eligible
      final coupon = coupons.firstWhere(
        (c) => c.code.toLowerCase() == _appliedCouponCode!.toLowerCase(),
        orElse: () => const CouponOffer(code: '', title: '', desc: '', minAmount: 0.0, imageUrl: ''),
      );
      if (coupon.code.isNotEmpty && cartSubtotal >= coupon.minAmount) {
        return _appliedCouponCode;
      }
    }
    
    // Otherwise, find the best eligible coupon automatically!
    CouponOffer? bestCoupon;
    double maxDiscount = -1.0;
    for (var coupon in coupons) {
      if (cartSubtotal >= coupon.minAmount) {
        double discount = 0.0;
        if (coupon.isFreeDelivery) {
          discount = deliveryFee;
        } else if (coupon.code == 'HDFC150') {
          discount = (cartSubtotal * 0.10).roundToDouble();
          if (discount > 150.0) discount = 150.0;
        } else if (coupon.discountPercent > 0) {
          discount = (cartSubtotal * coupon.discountPercent).roundToDouble();
        } else {
          discount = coupon.discountAmount;
        }

        if (discount > maxDiscount) {
          maxDiscount = discount;
          bestCoupon = coupon;
        }
      }
    }
    return bestCoupon?.code;
  }

  final List<CouponOffer> _coupons = [];
  List<CouponOffer> get coupons => _coupons;

  double get couponDiscount {
    final code = appliedCouponCode;
    if (code == null) return 0.0;
    final coupon = coupons.firstWhere(
      (c) => c.code.toLowerCase() == code.toLowerCase(),
      orElse: () => const CouponOffer(code: '', title: '', desc: '', minAmount: 0.0, imageUrl: ''),
    );
    if (coupon.code.isEmpty) return 0.0;
    if (cartSubtotal < coupon.minAmount) return 0.0;
    if (coupon.isFreeDelivery) return deliveryFee;
    if (coupon.code == 'HDFC150') {
      final double discount = (cartSubtotal * 0.10).roundToDouble();
      return discount > 150.0 ? 150.0 : discount;
    }
    if (coupon.discountPercent > 0) return (cartSubtotal * coupon.discountPercent).roundToDouble();
    return coupon.discountAmount;
  }

  void applyCoupon(String? couponCode) {
    _appliedCouponCode = couponCode;
    _couponRemovedManually = false;
    notifyListeners();
  }

  void removeCoupon() {
    _appliedCouponCode = null;
    _couponRemovedManually = true;
    notifyListeners();
  }

  String? _selectedDeliverySlot;
  String? get selectedDeliverySlot => _selectedDeliverySlot;

  void selectDeliverySlot(String? slot) {
    _selectedDeliverySlot = slot;
    notifyListeners();
  }

  // Base Fees
  double get deliveryFee => (cartSubtotal > 0 && !_isStorePickup) ? 30.0 : 0.0;
  bool get isDeliveryFree => cartSubtotal >= 139;
  double get activeDeliveryFee => isDeliveryFree ? 0.0 : deliveryFee;

  double get packagingFee => 0.0;
  bool get isHandlingFree => true;
  double get activeHandlingFee => 0.0;

  // Rs 2 Product Handling Charge
  double get handlingCharge => cartSubtotal > 0 ? 2.0 : 0.0;

  // Wallet State
  double _walletBalance = 0.0;
  double get walletBalance => _walletBalance;
  bool _useWallet = false;
  bool get useWallet => _useWallet;

  List<Map<String, dynamic>> _walletTransactions = [];
  List<Map<String, dynamic>> get walletTransactions => _walletTransactions;

  bool _hasClaimedReferralReward = false;
  bool get hasClaimedReferralReward => _hasClaimedReferralReward;

  void toggleUseWallet() {
    _useWallet = !_useWallet;
    notifyListeners();
  }

  Future<void> fetchWalletData() async {
    final uid = _userMobile ?? _supabaseService.currentUserId;
    if (uid.isEmpty) return;

    final cleanPhone = uid.replaceAll(RegExp(r'\D'), '');
    final phone10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final phone91 = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;

    // 1. Try fetching via Backend API (/api/wallet/balance/:userId)
    final cashfreeService = CashfreeService();
    final String activeBackend = cashfreeService.cloudBackendUrl ?? cashfreeService.backendBaseUrl;
    if (activeBackend.isNotEmpty) {
      try {
        final url = '${activeBackend.replaceAll(RegExp(r'/+$'), '')}/api/wallet/balance/$uid';
        final response = await http
            .get(Uri.parse(url), headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            _walletBalance = (data['balance'] as num?)?.toDouble() ?? _walletBalance;
            if (data['transactions'] != null) {
              _walletTransactions = List<Map<String, dynamic>>.from(data['transactions']);
            }
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('wallet_balance', _walletBalance);
            notifyListeners();
            return;
          }
        }
      } catch (_) {
        // Fallback to Supabase if backend is offline or slow
      }
    }

    // 2. Fetch directly from Supabase
    if (!_supabaseService.isSupabaseAvailable) return;

    try {
      // 1. Fetch latest wallet balance from users table (checking both formats)
      dynamic userRow;
      try {
        userRow = await _supabaseService.client!
            .from('users')
            .select('wallet_balance')
            .or('id.eq.$uid,mobile.eq.$uid,id.eq.$phone10,mobile.eq.$phone10,id.eq.$phone91,mobile.eq.$phone91')
            .maybeSingle();
      } catch (_) {
        userRow = await _supabaseService.client!
            .from('users')
            .select('wallet_balance')
            .eq('id', uid)
            .maybeSingle();
      }

      if (userRow != null && userRow['wallet_balance'] != null) {
        _walletBalance = (userRow['wallet_balance'] as num).toDouble();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('wallet_balance', _walletBalance);
      }

      // 2. Fetch transaction logs from wallet_transactions table
      dynamic txRows;
      try {
        txRows = await _supabaseService.client!
            .from('wallet_transactions')
            .select('*')
            .or('user_id.eq.$uid,user_id.eq.$phone10,user_id.eq.$phone91')
            .order('created_at', ascending: false)
            .limit(30);
      } catch (_) {
        txRows = await _supabaseService.client!
            .from('wallet_transactions')
            .select('*')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(30);
      }

      if (txRows != null) {
        _walletTransactions = List<Map<String, dynamic>>.from(txRows);
      }

      notifyListeners();
    } catch (e) {
      print("Error fetching wallet data: $e");
    }
  }

  /// Verifies payment with backend / Cashfree and credits the wallet balance securely
  Future<bool> creditWalletPayment({
    required String orderId,
    required double amount,
  }) async {
    final uid = _userMobile ?? _supabaseService.currentUserId;
    if (uid.isEmpty) return false;

    final cleanPhone = uid.replaceAll(RegExp(r'\D'), '');
    final phone10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final phone91 = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;

    try {
      // 1. Verify via Backend API
      final verification = await CashfreeService().verifyWalletPayment(
        orderId: orderId,
        userId: uid,
      );

      if (verification['success'] == true) {
        if (verification['newBalance'] != null) {
          _walletBalance = (verification['newBalance'] as num).toDouble();
        } else {
          _walletBalance += amount;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('wallet_balance', _walletBalance);
        await fetchWalletData();
        notifyListeners();
        return true;
      }

      // 2. If direct gateway verification succeeded (backend was offline), credit via Supabase
      if (verification['isDirectVerified'] == true) {
        if (_supabaseService.isSupabaseAvailable) {
          dynamic userRow;
          try {
            userRow = await _supabaseService.client!
                .from('users')
                .select('id, wallet_balance')
                .or('id.eq.$uid,mobile.eq.$uid,id.eq.$phone10,mobile.eq.$phone10,id.eq.$phone91,mobile.eq.$phone91')
                .maybeSingle();
          } catch (_) {
            userRow = await _supabaseService.client!
                .from('users')
                .select('id, wallet_balance')
                .eq('id', uid)
                .maybeSingle();
          }

          final targetId = userRow?['id']?.toString() ?? uid;
          double current = 0.0;
          if (userRow != null && userRow['wallet_balance'] != null) {
            current = (userRow['wallet_balance'] as num).toDouble();
          }
          final nextBalance = current + amount;

          await _supabaseService.client!
              .from('users')
              .update({'wallet_balance': nextBalance})
              .eq('id', targetId);

          await _supabaseService.client!
              .from('wallet_transactions')
              .insert({
                'user_id': targetId,
                'amount': amount,
                'type': 'deposit',
                'description': 'Added cash via Cashfree ($orderId)',
                'status': 'completed',
              });

          _walletBalance = nextBalance;
        } else {
          _walletBalance += amount;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('wallet_balance', _walletBalance);
        await fetchWalletData();
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      print("Error crediting wallet payment: $e");
      return false;
    }
  }

  Future<bool> depositMoney(double amount, {String? orderId}) async {
    if (orderId != null && orderId.isNotEmpty) {
      return creditWalletPayment(orderId: orderId, amount: amount);
    }

    final uid = _userMobile ?? _supabaseService.currentUserId;
    if (uid.isEmpty || !_supabaseService.isSupabaseAvailable) return false;

    try {
      final userRow = await _supabaseService.client!
          .from('users')
          .select('id, wallet_balance')
          .eq('id', uid)
          .maybeSingle();

      double current = 0.0;
      if (userRow != null && userRow['wallet_balance'] != null) {
        current = (userRow['wallet_balance'] as num).toDouble();
      }

      final nextBalance = current + amount;
      final targetId = userRow?['id']?.toString() ?? uid;

      await _supabaseService.client!
          .from('users')
          .update({'wallet_balance': nextBalance})
          .eq('id', targetId);

      await _supabaseService.client!
          .from('wallet_transactions')
          .insert({
            'user_id': targetId,
            'amount': amount,
            'type': 'deposit',
            'description': 'Added cash to wallet',
            'status': 'completed',
          });

      _walletBalance = nextBalance;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('wallet_balance', _walletBalance);
      await fetchWalletData();
      return true;
    } catch (e) {
      print("Error depositing money: $e");
      return false;
    }
  }

  void addWalletCash(double amount) {
    _walletBalance += amount;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('wallet_balance', _walletBalance);
    });
    if (_supabaseService.isSupabaseAvailable) {
      final uid = _userMobile ?? _supabaseService.currentUserId;
      if (uid.isNotEmpty) {
        _supabaseService.client!
            .from('users')
            .update({'wallet_balance': _walletBalance})
            .eq('id', uid)
            .then((_) {
              _supabaseService.client!.from('wallet_transactions').insert({
                'user_id': uid,
                'amount': amount,
                'type': 'deposit',
                'description': 'Referral reward cash credited',
                'status': 'completed',
              }).then((_) => fetchWalletData());
            });
      }
    }
    notifyListeners();
  }

  void claimReferralReward() {
    if (_hasClaimedReferralReward || _userMobile == null) return;
    _hasClaimedReferralReward = true;
    addWalletCash(100.0);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('has_claimed_referral_reward_$_userMobile', true);
    });
    notifyListeners();
  }

  double get walletDeduction {
    if (!_useWallet) return 0.0;
    final double rawTotal = (cartSubtotal + activeDeliveryFee + activeHandlingFee + handlingCharge - couponDiscount).clamp(0.0, double.infinity);
    return _walletBalance > rawTotal ? rawTotal : _walletBalance;
  }

  double get totalSavings => mrpDiscount + (isDeliveryFree ? deliveryFee : 0.0) + (isHandlingFree ? packagingFee : 0.0) + couponDiscount + walletDeduction;

  double get cartTotal => (cartSubtotal + activeDeliveryFee + activeHandlingFee + handlingCharge - couponDiscount - walletDeduction).clamp(0.0, double.infinity);

  int getMaxLimitForProduct(Product product) {
    final cat = (product.category ?? '').toLowerCase();
    final name = (product.name ?? '').toLowerCase();
    
    if (cat.contains('vegetable') || cat.contains('veg') || cat.contains('fruit')) {
      return 5; // Max 5 items/kg for fresh veggies and fruits
    } else if (cat.contains('dairy') || name.contains('milk') || name.contains('egg')) {
      return 10; // Max 10 units for milk/dairy/eggs
    } else if (cat.contains('grocery') || name.contains('atta') || name.contains('rice') || name.contains('dal')) {
      return 3; // Max 3 items for heavy grocery staples
    }
    return 5; // Default limit is 5 items per user order
  }

  // Global synchronized selected unit tracking across all screens
  final Map<String, String> _selectedProductUnits = {};

  static String normalizeUnit(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == '100 g' || s == '100g' || s == '100 gm' || s == '100gm') return '100g';
    if (s == '250 g' || s == '250g' || s == '250 gm' || s == '250gm') return '250g';
    if (s == '500 g' || s == '500g' || s == '500 gm' || s == '500gm') return '500g';
    if (s == '1 kg' || s == '1kg' || s == '1.0 kg' || s == '1.0kg' || s == '1.00 kg') return '1 kg';
    if (s == '1.5 kg' || s == '1.5kg') return '1.5 kg';
    if (s == '2 kg' || s == '2kg' || s == '2.0 kg' || s == '2.0kg') return '2 kg';
    if (s == '5 kg' || s == '5kg' || s == '5.0 kg' || s == '5.0kg') return '5 kg';
    if (s == '1 pcs' || s == '1pcs' || s == '1 piece' || s == '1 pc') return '1 pcs';
    return raw.trim();
  }

  static double? parseWeightInGrams(String raw) {
    final s = raw.trim().toLowerCase();
    // 1. Bracket format e.g. "1 pcs (500g)", "1 pcs (1 kg)", "1 pcs (1.5 kg)"
    final bracketMatch = RegExp(r'\(([\d.]+)\s*(kg|g|gm|grams)\)').firstMatch(s);
    if (bracketMatch != null) {
      final val = double.tryParse(bracketMatch.group(1)!);
      final u = bracketMatch.group(2)!;
      if (val != null && val > 0) {
        return u == 'kg' ? val * 1000.0 : val;
      }
    }

    // 2. Direct kg format e.g. "1 kg", "2kg", "0.5 kg", "1.5 kg", "5 kg"
    final kgMatch = RegExp(r'([\d.]+)\s*kg\b').firstMatch(s);
    if (kgMatch != null) {
      final val = double.tryParse(kgMatch.group(1)!);
      if (val != null && val > 0) return val * 1000.0;
    }

    // 3. Direct gram format e.g. "100g", "250 gm", "500g", "500 grams"
    final gMatch = RegExp(r'([\d.]+)\s*(g|gm|gram|grams)\b').firstMatch(s);
    if (gMatch != null) {
      final val = double.tryParse(gMatch.group(1)!);
      if (val != null && val > 0) return val;
    }

    return null;
  }

  bool hasProductVariants(Product product) {
    if (product.variants != null && product.variants!.length > 1) return true;
    final grams = parseWeightInGrams(product.unit);
    if (grams != null) return true;
    final u = product.unit.toLowerCase();
    return u.contains('kg') || u.contains('g') || u.contains('gm');
  }

  List<String> getProductUnitOptions(Product product) {
    final Set<String> options = {};

    // Include all normalized units from explicit variants if available
    if (product.variants != null && product.variants!.isNotEmpty) {
      for (final v in product.variants!) {
        final norm = normalizeUnit(v.unit);
        if (norm.isNotEmpty) options.add(norm);
      }
    }

    final String normBase = normalizeUnit(product.unit);
    options.add(normBase);

    // If it's a weight-based product (kg or gm), offer standard proportional weights
    final double? baseGrams = parseWeightInGrams(product.unit);
    if (baseGrams != null) {
      if (baseGrams <= 150) {
        options.addAll(['100g', '250g', '500g', '1 kg']);
      } else if (baseGrams <= 300) {
        options.addAll(['250g', '500g', '1 kg', '2 kg']);
      } else if (baseGrams <= 600) {
        options.addAll(['250g', '500g', '1 kg', '2 kg']);
      } else {
        options.addAll(['500g', '1 kg', '2 kg', '5 kg']);
      }
    }

    // Sort weight units by grams ascending for clean, logical ordering
    final List<String> list = options.toList();
    list.sort((a, b) {
      final gA = parseWeightInGrams(a);
      final gB = parseWeightInGrams(b);
      if (gA != null && gB != null) return gA.compareTo(gB);
      if (gA != null) return -1;
      if (gB != null) return 1;
      return a.compareTo(b);
    });

    return list.isNotEmpty ? list : [normBase];
  }

  String getProductSelectedUnit(Product product) {
    // 1. If product is already in cart, use the unit that's in the cart!
    final cartUnit = getCartUnitForProduct(product.id);
    if (cartUnit != null) {
      return cartUnit;
    }

    // 2. If the user previously selected a unit in this session, use it
    final cached = _selectedProductUnits[product.id];
    if (cached != null) {
      return cached;
    }

    // 3. Fallback to default product unit
    final options = getProductUnitOptions(product);
    final normUnit = normalizeUnit(product.unit);
    if (options.contains(normUnit)) {
      return normUnit;
    }
    return options.isNotEmpty ? options.first : normUnit;
  }

  void setProductSelectedUnit(String productId, String unit) {
    final normUnit = normalizeUnit(unit);
    _selectedProductUnits[productId] = normUnit;

    // Find if this product is already in the cart under ANY unit key
    String? matchedOldKey;
    CartItem? existingItem;
    for (final entry in _cart.entries) {
      if (entry.key.startsWith("${productId}_") ||
          entry.value.product.id == productId ||
          (entry.value.product.productId.isNotEmpty && entry.value.product.productId == productId)) {
        matchedOldKey = entry.key;
        existingItem = entry.value;
        break;
      }
    }

    if (matchedOldKey != null && existingItem != null && existingItem.selectedUnit != normUnit) {
      final liveProduct = findProductById(productId) ??
          findProductById(existingItem.product.id) ??
          (existingItem.product.productId.isNotEmpty ? findProductById(existingItem.product.productId) : null) ??
          existingItem.product;
      final prices = getProductPriceForUnit(liveProduct, normUnit);
      final double newPrice = prices['price'] ?? liveProduct.price;
      final double newOriginalPrice = prices['originalPrice'] ?? liveProduct.originalPrice;

      _cart.removeWhere((k, v) =>
          k.startsWith("${liveProduct.id}_") ||
          v.product.id == liveProduct.id ||
          (v.product.productId.isNotEmpty && v.product.productId == liveProduct.id));

      final newKey = "${liveProduct.id}_$normUnit";
      _cart[newKey] = CartItem(
        product: liveProduct,
        quantity: existingItem.quantity,
        selectedUnit: normUnit,
        price: newPrice,
        originalPrice: newOriginalPrice,
      );
      _persistCartLocally();
      final uid = userMobile ?? _supabaseService.currentUserId;
      if (uid.isNotEmpty) {
        _supabaseService.saveCartItem(uid, liveProduct.id, existingItem.quantity, imageUrl: liveProduct.imageUrl);
      }
    }
    notifyListeners();
  }

  String? getCartUnitForProduct(String productId) {
    for (final entry in _cart.entries) {
      if (entry.key.startsWith("${productId}_") ||
          entry.value.product.id == productId ||
          (entry.value.product.productId.isNotEmpty && entry.value.product.productId == productId)) {
        return entry.value.selectedUnit;
      }
    }
    return null;
  }

  Map<String, double> getProductPriceForUnit(Product product, String unit) {
    final targetUnit = normalizeUnit(unit);

    // 1. Check if an explicit variant has an exact match
    if (product.variants != null && product.variants!.isNotEmpty) {
      final exactMatch = product.variants!.firstWhere(
        (v) => normalizeUnit(v.unit).toLowerCase() == targetUnit.toLowerCase(),
        orElse: () => ProductVariantOption(unit: '', price: -1, originalPrice: -1),
      );
      if (exactMatch.price > 0) {
        return {
          'price': exactMatch.price,
          'originalPrice': exactMatch.originalPrice > 0 ? exactMatch.originalPrice : exactMatch.price,
        };
      }
    }

    // 2. Dynamic proportional weight calculation for kg and gm
    final double? targetGrams = parseWeightInGrams(targetUnit);
    if (targetGrams != null && targetGrams > 0) {
      double baseGrams = 0;
      double basePrice = product.price;
      double baseOriginalPrice = product.originalPrice;

      // First check if base product.unit has grams
      final double? pGrams = parseWeightInGrams(product.unit);
      if (pGrams != null && pGrams > 0 && product.price > 0) {
        baseGrams = pGrams;
        basePrice = product.price;
        baseOriginalPrice = product.originalPrice > 0 ? product.originalPrice : product.price;
      } else if (product.variants != null && product.variants!.isNotEmpty) {
        // Find reference variant with known weight and price
        for (final v in product.variants!) {
          final double? vGrams = parseWeightInGrams(v.unit);
          if (vGrams != null && vGrams > 0 && v.price > 0) {
            baseGrams = vGrams;
            basePrice = v.price;
            baseOriginalPrice = v.originalPrice > 0 ? v.originalPrice : v.price;
            break;
          }
        }
      }

      if (baseGrams > 0 && basePrice > 0) {
        final double ratio = targetGrams / baseGrams;
        final double dynamicPrice = (basePrice * ratio).roundToDouble();
        final double dynamicOriginalPrice = (baseOriginalPrice * ratio).roundToDouble();
        return {
          'price': dynamicPrice > 0 ? dynamicPrice : 1.0,
          'originalPrice': dynamicOriginalPrice >= dynamicPrice ? dynamicOriginalPrice : dynamicPrice,
        };
      }
    }

    // Fallback: return default base price
    return {
      'price': product.price > 0 ? product.price : 1.0,
      'originalPrice': product.originalPrice >= product.price ? product.originalPrice : product.price,
    };
  }

  void setProductQuantity(Product product, int targetQty, {String? selectedUnit}) {
    final liveProduct = findProductById(product.id) ??
        (product.productId.isNotEmpty ? findProductById(product.productId) : null) ??
        product;

    final String unit = normalizeUnit(selectedUnit ?? getProductSelectedUnit(liveProduct));
    final String key = "${liveProduct.id}_$unit";
    final int maxLimit = getMaxLimitForProduct(liveProduct);
    final int safeQty = targetQty > maxLimit ? maxLimit : targetQty;

    // Clean up any other unit entries for this product
    _cart.removeWhere((k, v) =>
        (k.startsWith("${liveProduct.id}_") ||
            v.product.id == liveProduct.id ||
            (v.product.productId.isNotEmpty && v.product.productId == liveProduct.id)) &&
        k != key);

    final prices = getProductPriceForUnit(liveProduct, unit);
    final double freshPrice = prices['price'] ?? liveProduct.price;
    final double freshOrigPrice = prices['originalPrice'] ?? liveProduct.originalPrice;

    if (safeQty <= 0) {
      _cart.remove(key);
    } else {
      if (_cart.containsKey(key)) {
        _cart[key] = _cart[key]!.copyWith(
          product: liveProduct,
          quantity: safeQty,
          price: freshPrice,
          originalPrice: freshOrigPrice,
        );
      } else {
        _cart[key] = CartItem(
          product: liveProduct,
          quantity: safeQty,
          selectedUnit: unit,
          price: freshPrice,
          originalPrice: freshOrigPrice,
        );
      }
    }
    _persistCartLocally();
    final uid = userMobile ?? _supabaseService.currentUserId;
    if (uid.isNotEmpty) {
      if (safeQty <= 0) {
        _supabaseService.removeFromCartFromDb(uid, liveProduct.id);
      } else {
        _supabaseService.saveCartItem(uid, liveProduct.id, safeQty, imageUrl: liveProduct.imageUrl);
      }
    }
    _couponRemovedManually = false;
    notifyListeners();
  }

  void addToCart(Product product, {String? selectedUnit, double? price, double? originalPrice}) {
    if (_outOfStockProductIds.contains(product.id)) return;

    final liveProduct = findProductById(product.id) ??
        (product.productId.isNotEmpty ? findProductById(product.productId) : null) ??
        product;

    final String unit = normalizeUnit(selectedUnit ?? getProductSelectedUnit(liveProduct));
    final String key = "${liveProduct.id}_$unit";
    final int maxLimit = getMaxLimitForProduct(liveProduct);

    // Save as active selected unit globally across all screens
    _selectedProductUnits[liveProduct.id] = unit;

    // Fresh live prices for this unit
    final unitPrices = getProductPriceForUnit(liveProduct, unit);
    final double freshPrice = unitPrices['price'] ?? liveProduct.price;
    final double freshOrigPrice = unitPrices['originalPrice'] ?? liveProduct.originalPrice;

    // Check if this product is already in the cart with ANY unit
    final existingCartUnit = getCartUnitForProduct(liveProduct.id);
    if (existingCartUnit != null && existingCartUnit != unit) {
      // Product already in cart under another unit -> MIGRATE to new unit and increment!
      // This strictly prevents duplicate product entries with different units in the cart.
      final oldKey = "${liveProduct.id}_$existingCartUnit";
      final oldItem = _cart.remove(oldKey);
      final int preservedQty = oldItem != null ? oldItem.quantity : 1;

      _cart[key] = CartItem(
        product: liveProduct,
        quantity: preservedQty < maxLimit ? preservedQty + 1 : maxLimit,
        selectedUnit: unit,
        price: freshPrice,
        originalPrice: freshOrigPrice,
      );
      _persistCartLocally();
      final uid = userMobile ?? _supabaseService.currentUserId;
      if (uid.isNotEmpty) {
        final int newQty = _cart[key]?.quantity ?? 0;
        _supabaseService.saveCartItem(uid, liveProduct.id, newQty, imageUrl: liveProduct.imageUrl);
      }
      _couponRemovedManually = false;
      notifyListeners();
      return;
    }

    if (_cart.containsKey(key)) {
      final existing = _cart[key]!;
      final int newQty = existing.quantity < maxLimit ? existing.quantity + 1 : maxLimit;
      _cart[key] = existing.copyWith(
        product: liveProduct,
        quantity: newQty,
        price: freshPrice,
        originalPrice: freshOrigPrice,
      );
    } else {
      _cart[key] = CartItem(
        product: liveProduct,
        quantity: 1,
        selectedUnit: unit,
        price: freshPrice,
        originalPrice: freshOrigPrice,
      );
    }
    _persistCartLocally();
    final uid = userMobile ?? _supabaseService.currentUserId;
    if (uid.isNotEmpty) {
      final int newQty = _cart[key]?.quantity ?? 0;
      if (newQty > 0) {
        _supabaseService.saveCartItem(uid, liveProduct.id, newQty, imageUrl: liveProduct.imageUrl);
      }
    }
    _couponRemovedManually = false;
    notifyListeners();
  }

  void removeFromCart(Product product, {String? selectedUnit}) {
    final String unit = normalizeUnit(selectedUnit ?? getProductSelectedUnit(product));
    String key = "${product.id}_$unit";

    // Fallback: if not found by this key, check if product exists under another unit key
    if (!_cart.containsKey(key)) {
      final inCartUnit = getCartUnitForProduct(product.id);
      if (inCartUnit != null) {
        key = "${product.id}_$inCartUnit";
      } else {
        return;
      }
    }

    int newQty = 0;
    if (_cart[key]!.quantity > 1) {
      final existing = _cart[key]!;
      final liveProduct = findProductById(product.id) ??
          (product.productId.isNotEmpty ? findProductById(product.productId) : null) ??
          existing.product;
      final prices = getProductPriceForUnit(liveProduct, existing.selectedUnit);
      newQty = existing.quantity - 1;
      _cart[key] = existing.copyWith(
        product: liveProduct,
        quantity: newQty,
        price: prices['price'] ?? liveProduct.price,
        originalPrice: prices['originalPrice'] ?? liveProduct.originalPrice,
      );
    } else {
      _cart.remove(key);
    }
    _persistCartLocally();
    final uid = userMobile ?? _supabaseService.currentUserId;
    if (uid.isNotEmpty) {
      if (newQty > 0) {
        _supabaseService.saveCartItem(uid, product.id, newQty, imageUrl: product.imageUrl);
      } else {
        _supabaseService.removeFromCartFromDb(uid, product.id);
      }
    }
    _couponRemovedManually = false;
    notifyListeners();
  }

  void deleteFromCart(Product product, {String? selectedUnit}) {
    final String unit = normalizeUnit(selectedUnit ?? getProductSelectedUnit(product));
    String key = "${product.id}_$unit";
    if (!_cart.containsKey(key)) {
      final inCartUnit = getCartUnitForProduct(product.id);
      if (inCartUnit != null) {
        key = "${product.id}_$inCartUnit";
      }
    }
    _cart.remove(key);
    _persistCartLocally();
    final uid = userMobile ?? _supabaseService.currentUserId;
    if (uid.isNotEmpty) {
      _supabaseService.removeFromCartFromDb(uid, product.id);
    }
    _couponRemovedManually = false;
    notifyListeners();
  }

  int getProductQuantity(String productId, {String? selectedUnit}) {
    if (selectedUnit != null) {
      final norm = normalizeUnit(selectedUnit);
      final key = "${productId}_$norm";
      if (_cart.containsKey(key)) {
        return _cart[key]!.quantity;
      }
    }
    // Check if product is in cart under any unit
    int total = 0;
    _cart.forEach((key, item) {
      if (key.startsWith("${productId}_") ||
          item.product.id == productId ||
          (item.product.productId.isNotEmpty && item.product.productId == productId)) {
        total += item.quantity;
      }
    });
    return total;
  }

  // Addresses State
  final List<Address> _addresses = [];

  List<Address> get addresses => _addresses;

  Address? get selectedAddress {
    if (_addresses.isNotEmpty) {
      return _addresses.firstWhere(
        (a) => a.isSelected,
        orElse: () => _addresses.first,
      );
    }
    return Address(
      id: 'default_location_addr',
      title: 'Home',
      fullName: (userName.isNotEmpty && userName != 'User Name') ? userName : 'Customer',
      mobile: userMobile ?? '9876543210',
      addressLine: _userCurrentLocation.isNotEmpty ? _userCurrentLocation : '123, MG Road, Darbhanga',
      landmark: 'Near City Landmark',
      city: 'Darbhanga',
      pinCode: '846004',
      isSelected: true,
    );
  }

  Future<void> _saveAddressesToLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> addressStrings = _addresses.map((addr) {
        return json.encode(addr.toJson());
      }).toList();
      await prefs.setStringList('local_addresses_cache', addressStrings);
    } catch (e) {
      print("Error saving addresses to local cache: $e");
    }
  }

  void selectAddress(String addressId) {
    Address? selected;
    for (var addr in _addresses) {
      addr.isSelected = (addr.id == addressId);
      if (addr.isSelected) {
        selected = addr;
        _userCurrentLocation = addr.addressLine;
        setHasSelectedLocation(true);
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('user_current_location', addr.addressLine);
        });
      }
    }
    _saveAddressesToLocalCache();
    notifyListeners();

    if (selected != null) {
      final uid = userMobile ?? _supabaseService.currentUserId;
      _supabaseService.saveAddress(uid, selected);
    }
  }

  void addAddress(Address address) {
    if (address.isSelected) {
      for (var addr in _addresses) {
        addr.isSelected = false;
      }
      _userCurrentLocation = address.addressLine;
      setHasSelectedLocation(true);
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('user_current_location', address.addressLine);
      });
    }

    final existingIndex = _addresses.indexWhere((a) => a.id == address.id);
    if (existingIndex != -1) {
      _addresses[existingIndex] = address;
    } else {
      _addresses.add(address);
    }

    _saveAddressesToLocalCache();
    notifyListeners();

    final uid = userMobile ?? _supabaseService.currentUserId;
    _supabaseService.saveAddress(uid, address);
  }

  String generateUuid() {
    final Random random = Random();
    final List<int> values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<String?> validateCartAndCheckout() async {
    if (_cart.isEmpty) return null;
    if (!_supabaseService.isSupabaseAvailable) return null;

    try {
      // Use real product/variant IDs from cart items, NOT composite map keys with '_unit'
      final List<String> variantIds = _cart.values
          .map((item) => item.product.id)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (variantIds.isEmpty) return null;

      final response = await _supabaseService.client!
          .from('product_variants')
          .select('*, products(*, categories(*))')
          .inFilter('id', variantIds);

      // If database variants query returns empty, verify against local out of stock list
      // and allow checkout to proceed without wiping the cart!
      if (response == null || (response as List).isEmpty) {
        for (final item in _cart.values) {
          if (_outOfStockProductIds.contains(item.product.id)) {
            return "${item.product.name} is currently out of stock.";
          }
        }
        return null;
      }

      final Map<String, dynamic> dbVariants = {
        for (var row in (response as List)) row['id'].toString(): row
      };

      bool cartUpdated = false;
      List<String> messages = [];

      for (final cartKey in _cart.keys.toList()) {
        final cartItem = _cart[cartKey];
        if (cartItem == null) continue;

        final dbRow = dbVariants[cartItem.product.id];
        if (dbRow == null) {
          continue;
        }

        final productRow = dbRow['products'];
        if (productRow == null) {
          continue;
        }

        final String status = productRow['status']?.toString() ?? 'active';
        final int stockTotal = int.tryParse(dbRow['stock_total']?.toString() ?? '0') ?? 0;
        final bool isSoldOut = stockTotal <= 0 || status == 'sold_out' || status == 'inactive';

        if (isSoldOut) {
          _cart.remove(cartKey);
          cartUpdated = true;
          messages.add("${cartItem.product.name} is currently out of stock.");
          continue;
        }

        if (cartItem.quantity > stockTotal && stockTotal > 0) {
          cartItem.quantity = stockTotal;
          cartUpdated = true;
          messages.add("Only $stockTotal units of ${cartItem.product.name} are available.");
          continue;
        }
      }

      if (cartUpdated) {
        _persistCartLocally();
        notifyListeners();
        return messages.isNotEmpty ? messages.join("\n") : null;
      }

      return null;
    } catch (e) {
      print("Warning during cart validation: $e");
      // Do not block order placement if a network/validation glitch occurs
      return null;
    }
  }

  // Orders State
  final List<Order> _orders = [];

  List<Order> get orders => _orders;

  void placeOrder(String paymentMethod, {String? instructions, double? customAmount, String? customOrderId}) {
    if (_cart.isEmpty) return;

    final double walletUsed = walletDeduction;
    final uid = userMobile ?? _supabaseService.currentUserId;
    if (_useWallet && walletUsed > 0) {
      _walletBalance -= walletUsed;
      _useWallet = false;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setDouble('wallet_balance', _walletBalance);
      });
      
      if (_supabaseService.isSupabaseAvailable && uid.isNotEmpty) {
        _supabaseService.client!
            .from('users')
            .update({'wallet_balance': _walletBalance})
            .eq('id', uid)
            .then((_) {
              _supabaseService.client!.from('wallet_transactions').insert({
                'user_id': uid,
                'amount': -walletUsed,
                'type': 'purchase',
                'description': 'Order payment using wallet',
                'status': 'completed',
              }).then((_) => fetchWalletData());
            });
      }
    }

    final String newOrderId = customOrderId ??
        'SW${(DateTime.now().millisecondsSinceEpoch % 10000000000).toString().padLeft(10, '0')}';
    final double amount = customAmount ?? cartTotal;
    final String devTime = _selectedDeliverySlot != null
        ? 'Scheduled: $_selectedDeliverySlot'
        : (instructions != null && instructions.trim().isNotEmpty)
            ? '14 mins (Note: $instructions)'
            : '14 mins';

    final String pmLower = paymentMethod.toLowerCase();
    final String normPaymentMethod;
    final String paymentStatusVal;
    if (pmLower == 'cod') {
      normPaymentMethod = 'COD';
      paymentStatusVal = 'pending';
    } else if (pmLower == 'upi') {
      normPaymentMethod = 'UPI';
      paymentStatusVal = 'paid';
    } else if (pmLower == 'card' || pmLower.contains('card') || pmLower.contains('debit') || pmLower.contains('credit')) {
      normPaymentMethod = 'CARD';
      paymentStatusVal = 'paid';
    } else if (pmLower == 'wallet') {
      normPaymentMethod = 'WALLET';
      paymentStatusVal = 'paid';
    } else {
      normPaymentMethod = paymentMethod.toUpperCase();
      paymentStatusVal = 'paid';
    }

    final String custName = userName.isNotEmpty && userName != "User Name" ? userName : 'Customer';
    final String custPhone = userMobile ?? '';

    final String deliveryAddressText = selectedAddress != null
        ? '${selectedAddress!.addressLine}, ${selectedAddress!.city} - ${selectedAddress!.pinCode}'
        : _userCurrentLocation;

    final newOrder = Order(
      id: newOrderId,
      date: DateTime.now(),
      status: 'placed',
      items: List<CartItem>.from(cartItems),
      totalAmount: amount,
      deliveryTime: devTime,
      paymentMethod: normPaymentMethod,
      paymentStatus: paymentStatusVal,
      customerName: custName,
      customerPhone: custPhone,
      deliveryAddress: deliveryAddressText,
    );

    _orders.insert(0, newOrder);
    _cart.clear();
    _isStorePickup = false;
    _selectedDeliverySlot = null;
    _persistCartLocally();
    notifyListeners();

    if (uid.isNotEmpty) {
      _supabaseService.clearCartFromDb(uid);
    }

    // Ensure address exists in DB — user_id must match users.id (mobile)
    String addressId = selectedAddress?.id ?? '';
    if (addressId.isEmpty) {
      final fallbackAddress = Address(
        id: generateUuid(),
        title: 'Home',
        fullName: userName.isNotEmpty ? userName : 'Customer',
        mobile: uid,
        addressLine: _userCurrentLocation,
        landmark: '',
        city: 'Darbhanga',
        pinCode: '846004',
        isSelected: true,
      );
      addAddress(fallbackAddress);
      addressId = fallbackAddress.id;
    }

    _supabaseService.placeOrder(
      uid,
      newOrder,
      addressId,
      paymentMethod: normPaymentMethod,
      deliveryFee: activeDeliveryFee,
      deliveryAddress: deliveryAddressText,
    );
  }

  void updateOrderStatus(String orderId, String newStatus) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final old = _orders[index];
      _orders[index] = Order(
        id: old.id,
        date: old.date,
        status: newStatus,
        items: old.items,
        totalAmount: old.totalAmount,
        deliveryTime: newStatus == 'delivered'
            ? 'Delivered'
            : newStatus == 'cancelled'
                ? 'Cancelled'
                : old.deliveryTime,
      );
      notifyListeners();

      if (_supabaseService.isSupabaseAvailable) {
        try {
          await _supabaseService.client!
              .from('orders')
              .update({'order_status': newStatus})
              .eq('id', orderId);
        } catch (e) {
          print("Failed to sync order status update: $e");
        }
      }
    }
  }

  Future<void> addProduct(Product product) async {
    _products.add(product);
    notifyListeners();

    if (_supabaseService.isSupabaseAvailable) {
      try {
        final catId = product.category.toLowerCase().replaceAll(' ', '_');
        await _supabaseService.client!.from('products').insert({
          'id': product.id,
          'category_id': catId,
          'sub_category_id': product.subCategoryId.isNotEmpty ? product.subCategoryId : null,
          'name': product.name,
          'description': product.description,
          'is_organic': product.isOrganic,
          'status': product.status,
          'image_url': product.imageUrl,
        });
        final parts = product.unit.trim().split(RegExp(r'\s+'));
        final weight = double.tryParse(parts.first) ?? 1.0;
        final unit = parts.length > 1 ? parts[1].toLowerCase() : 'pcs';
        await _supabaseService.client!.from('product_variants').insert({
          'id': '${product.id}_v1',
          'product_id': product.id,
          'weight': weight,
          'unit': unit,
          'mrp': product.originalPrice,
          'selling_price': product.price,
          'sku': 'SKU_${product.id.toUpperCase()}',
        });
        print("Product added to Supabase successfully.");
      } catch (e) {
        print("Failed to add product to Supabase: $e");
      }
    }
  }

  StreamSubscription? _stockSub;

  void _listenToStockUpdates() {
    if (_supabaseService.isSupabaseAvailable) {
      _stockSub = _supabaseService.client!
          .from('settings')
          .stream(primaryKey: ['key'])
          .eq('key', 'out_of_stock_ids')
          .listen((data) {
            if (data.isNotEmpty) {
              final String val = data.first['value'] ?? '';
              _outOfStockProductIds.clear();
              if (val.isNotEmpty) {
                _outOfStockProductIds.addAll(val.split(','));
              }
              notifyListeners();
            }
          });
    }
  }

  void toggleStockStatus(String productId) async {
    if (_outOfStockProductIds.contains(productId)) {
      _outOfStockProductIds.remove(productId);
    } else {
      _outOfStockProductIds.add(productId);
    }
    notifyListeners();

    if (_supabaseService.isSupabaseAvailable) {
      try {
        await _supabaseService.client!.from('settings').upsert({
          'key': 'out_of_stock_ids',
          'value': _outOfStockProductIds.join(','),
        });
        print("Stock status synced to Supabase successfully.");
      } catch (e) {
        print("Failed to sync stock status to Supabase: $e");
      }
    }
  }

  bool isProductInStock(String productId) {
    if (_outOfStockProductIds.contains(productId)) return false;
    for (var p in _products) {
      if (p.id == productId || p.productId == productId) {
        return !p.isSoldOut;
      }
    }
    return true;
  }

  // Favorites / Wishlist State
  final Set<String> _favoriteProductIds = {};
  Set<String> get favoriteProductIds => _favoriteProductIds;

  bool isFavorite(String productId) => _favoriteProductIds.contains(productId);

  Future<void> _loadWishlistFromDb(String userId) async {
    final ids = await _supabaseService.fetchWishlist(userId);
    if (ids.isNotEmpty) {
      _favoriteProductIds.clear();
      _favoriteProductIds.addAll(ids);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_product_ids', ids);
      notifyListeners();
    }
  }

  void toggleFavorite(String productId) async {
    final uid = userMobile ?? _supabaseService.currentUserId;
    if (_favoriteProductIds.contains(productId)) {
      _favoriteProductIds.remove(productId);
      _supabaseService.removeFromWishlist(uid, productId);
    } else {
      _favoriteProductIds.add(productId);
      _supabaseService.addToWishlist(uid, productId);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_product_ids', _favoriteProductIds.toList());
    } catch (e) {
      print("Failed to persist favorites: $e");
    }
  }

  List<Product> get favoriteProducts =>
      _products.where((p) => _favoriteProductIds.contains(p.id)).toList();

  Future<void> _persistCartLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> cartData = _cart.values.map((item) {
        return json.encode({
          'product_id': item.product.id,
          'quantity': item.quantity,
          'selected_unit': item.selectedUnit,
          'price': item.price,
          'original_price': item.originalPrice,
        });
      }).toList();
      await prefs.setStringList('local_cart_cache', cartData);
    } catch (e) {
      print("Failed to persist cart locally: $e");
    }
  }

  Future<void> _loadCartLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? cartData = prefs.getStringList('local_cart_cache');
      if (cartData != null && cartData.isNotEmpty) {
        _cart.clear();
        for (final itemStr in cartData) {
          final Map<String, dynamic> itemMap = json.decode(itemStr) as Map<String, dynamic>;
          final String prodId = itemMap['product_id'] as String;
          final int qty = itemMap['quantity'] as int;
          final String unit = itemMap['selected_unit'] as String;

          final Product? prod = findProductById(prodId);

          if (prod != null) {
            final String key = "${prod.id}_$unit";
            final prices = getProductPriceForUnit(prod, unit);
            _cart[key] = CartItem(
              product: prod,
              quantity: qty,
              selectedUnit: unit,
              price: prices['price'] ?? prod.price,
              originalPrice: prices['originalPrice'] ?? prod.originalPrice,
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      print("Failed to load cart locally: $e");
    }
  }

  Future<void> _loadCartFromDb(String userId) async {
    final dbCart = await _supabaseService.fetchCart(userId);
    if (dbCart.isNotEmpty) {
      for (final row in dbCart) {
        final String? varId = row['variant_id'] as String?;
        final int? qty = row['quantity'] as int?;
        if (varId != null && qty != null && qty > 0) {
          final Product? prod = findProductById(varId);
          if (prod != null) {
            // Only add if this product is not already present in the cart under any unit
            final inCartUnit = getCartUnitForProduct(prod.id);
            if (inCartUnit == null) {
              final String unit = normalizeUnit(prod.unit);
              final String key = "${prod.id}_$unit";
              final prices = getProductPriceForUnit(prod, unit);
              _cart[key] = CartItem(
                product: prod,
                quantity: qty,
                selectedUnit: unit,
                price: prices['price'] ?? prod.price,
                originalPrice: prices['originalPrice'] ?? prod.originalPrice,
              );
            }
          }
        }
      }
      _persistCartLocally();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stockSub?.cancel();
    _addressesSub?.cancel();
    _heartbeatTimer?.cancel();
    if (_catalogSubscription != null && _supabaseService.isSupabaseAvailable) {
      try {
        _supabaseService.client!.removeChannel(_catalogSubscription!);
      } catch (_) {}
    }
    super.dispose();
  }
}
