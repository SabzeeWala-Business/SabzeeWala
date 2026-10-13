import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'product_detail_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'address_screen.dart';
import '../widgets/product_image.dart';
import '../services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  int _activeSliderIndex = 0;
  late final PageController _pageController;
  bool _didCheckLocation = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
    SupabaseService().updateUserActivity('browsing');
  }

  void _showStartupLocationPrompt() async {
    final appState = Provider.of<AppState>(context, listen: false);
    // Mark as prompt shown so it never pops up again automatically
    await appState.setHasSelectedLocation(true);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                "Select Location Preference",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Choose how you want to set your delivery location for fresh groceries.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.my_location),
                label: const Text("Use Live Location (GPS)"),
                onPressed: () {
                  Navigator.pop(context);
                  _getLiveLocation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text("Enter Location Manually"),
                onPressed: () {
                  Navigator.pop(context);
                  _showManualLocationBottomSheet();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSavedAddressesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer<AppState>(
          builder: (context, appState, child) {
            final List<Address> savedAddresses = appState.addresses;
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        "Select Delivery Address",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (savedAddresses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        "No saved addresses yet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: savedAddresses.length,
                        itemBuilder: (context, index) {
                          final address = savedAddresses[index];
                          return GestureDetector(
                            onTap: () {
                              appState.selectAddress(address.id);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Delivery address set to: ${address.title}"),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: address.isSelected
                                    ? AppColors.primary.withOpacity(0.05)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: address.isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade200,
                                  width: address.isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    address.isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: address.isSelected
                                        ? AppColors.primary
                                        : Colors.grey.shade400,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          address.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          address.addressLine,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            height: 1.3,
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
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text("Use Current GPS Location"),
                    onPressed: () {
                      Navigator.pop(context);
                      _getLiveLocation();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                    label: const Text("Add / Edit Saved Addresses"),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AddressScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _getLiveLocation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final appState = Provider.of<AppState>(context, listen: false);
    try {
      await appState.determineAndSetLiveLocation();
      if (mounted) {
        setState(() {}); // Refresh home screen header immediately
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Live location set: ${appState.userCurrentLocation}"),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to fetch location: $e. Please enter manually.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showManualLocationBottomSheet() {
    final formKey = GlobalKey<FormState>();
    final appState = Provider.of<AppState>(context, listen: false);

    final mobileController = TextEditingController(text: appState.userMobile ?? "9876543210");
    final flatController = TextEditingController();
    final areaController = TextEditingController();
    final landmarkController = TextEditingController();
    final cityController = TextEditingController(text: "Darbhanga");
    final pinController = TextEditingController(text: "846004");
    String selectedTag = 'Home';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Add Delivery Address",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Contact Mobile Number
                      TextFormField(
                        controller: mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Mobile Number',
                          labelStyle: TextStyle(color: AppColors.textLight),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) => v == null || v.length != 10 ? 'Enter 10-digit mobile number' : null,
                      ),
                      const SizedBox(height: 12),

                      // Flat No & Building Name
                      TextFormField(
                        controller: flatController,
                        decoration: const InputDecoration(
                          labelText: 'Flat / House No. / Building Name',
                          labelStyle: TextStyle(color: AppColors.textLight),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Area & Street
                      TextFormField(
                        controller: areaController,
                        decoration: const InputDecoration(
                          labelText: 'Area / Colony / Street / Road',
                          labelStyle: TextStyle(color: AppColors.textLight),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Landmark (Optional)
                      TextFormField(
                        controller: landmarkController,
                        decoration: const InputDecoration(
                          labelText: 'Landmark (Optional)',
                          labelStyle: TextStyle(color: AppColors.textLight),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // City & Pincode
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cityController,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                labelStyle: TextStyle(color: AppColors.textLight),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: pinController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Pincode',
                                labelStyle: TextStyle(color: AppColors.textLight),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              validator: (v) => v == null || v.length != 6 ? 'Enter 6 digits' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Address Tag (Home, Office, Other)
                      const Text(
                        "Save Address As",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['Home', 'Office', 'Other'].map((tag) {
                          final isSelected = selectedTag == tag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: ChoiceChip(
                              label: Text(tag),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.primary : Colors.grey.shade700,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  selectedTag = tag;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final flat = flatController.text.trim();
                            final area = areaController.text.trim();
                            final landmarkStr = landmarkController.text.trim();
                            final city = cityController.text.trim();
                            final pin = pinController.text.trim();

                            final fullAddressLine = "$flat, $area";

                            final newAddr = Address(
                              id: appState.generateUuid(),
                              title: selectedTag,
                              fullName: appState.userName.isNotEmpty ? appState.userName : 'Valued Customer',
                              mobile: mobileController.text.trim(),
                              addressLine: fullAddressLine,
                              landmark: landmarkStr.isNotEmpty ? landmarkStr : 'None',
                              city: city,
                              pinCode: pin,
                              isSelected: true,
                            );

                            appState.addAddress(newAddr);
                            setState(() {}); // refresh Home Screen header immediately

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Address saved & location set to $selectedTag!"),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Save Address & Set Location",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appState = Provider.of<AppState>(context);

    final bool hasCustomAddress = appState.addresses.any((a) => a.id != 'default_location_addr');
    if (!appState.isAuthLoading && !appState.hasSelectedLocation && !hasCustomAddress && !_didCheckLocation) {
      _didCheckLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showStartupLocationPrompt();
        }
      });
    }

    // Live products from Supabase DB
    final allProducts = appState.products;
    final List<Product> bestSellers = [];
    final List<Product> organicVegetables = allProducts
        .where((p) => [
              'veg_tomato',
              'veg_cabbage',
              'veg_potato',
              'veg_cauliflower',
              'veg_cucumber',
              'veg_capsicum'
            ].contains(p.id))
        .toList();

    final List<Product> newLaunchProducts = allProducts
        .where((p) => [
              'fr_kiwi',
              'fr_kashmiri_guava',
              'dy_ice_cream',
              'bv_sting_energy_drink'
            ].contains(p.id))
        .toList();



    return Scaffold(
      backgroundColor: const Color(
        0xFFF9FBF9,
      ), // matching the soft green-grey background
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => Provider.of<AppState>(context, listen: false).refreshCatalog(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // 1. WAVY GREEN HEADER CONTAINER (using ClipPath and HeaderWaveClipper)
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Layered double wave line border at the bottom (Background Layer)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: HeaderWaveClipperBorder(),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF81C784), // Light Green outline
                              Color(0xFFA5D6A7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Main ClipPath (Foreground Layer)
                ClipPath(
                  clipper: HeaderWaveClipper(),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1B5E20), // Dark Green
                          Color(0xFF2E7D32), // Brand Green
                          Color(0xFF388E3C), // Light Green
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      right: 16,
                      bottom: 30, // Deeper wave padding
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Row 1: Location on Left, Notification + Avatar on Right
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _showSavedAddressesBottomSheet,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Deliver to',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  appState.selectedAddress != null && appState.selectedAddress!.addressLine.isNotEmpty
                                                      ? appState.selectedAddress!.addressLine
                                                      : appState.userCurrentLocation,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.keyboard_arrow_down,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: () {
                                Provider.of<AppState>(context, listen: false).setNavIndex(3);
                              },
                              child: Container(
                                height: 36,
                                width: 36,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/user_avatar.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Row 2: Brand Logo and Title
                        Row(
                          children: [
                            Container(
                              height: 36,
                              width: 36,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/sabzee_logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SabzeeWala',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Text(
                                      'Fresh groceries at your doorstep',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.eco,
                                      color: Colors.green.shade200,
                                      size: 10,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 3: Integrated Search Bar (No overlapping trick needed!)
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.search,
                                color: AppColors.textLight,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SearchScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Search vegetables, fruits, dairy...',
                                    style: TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const FavoritesScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFEBEE),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Row 4: Categories Selector Pills (Horizontal list inside Green Header)
                        SizedBox(
                          height: 52, // Compact size to fit 5+ items
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildCategoryPill(
                                title: 'All',
                                icon: Icons.grid_view_rounded,
                                isActive: true,
                                onTap: () => appState.setNavIndex(1),
                              ),
                              ...appState.categories.map((cat) {
                                return _buildCategoryPill(
                                  title: cat.name,
                                  image: cat.imageUrl.isNotEmpty ? cat.imageUrl : null,
                                  icon: cat.imageUrl.isEmpty ? Icons.eco_rounded : null,
                                  isActive: false,
                                  onTap: () {
                                    appState.setSelectedCategoryByName(cat.name);
                                    appState.setNavIndex(1);
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Decorative Leaf Icon 1 (Bottom Left)
                Positioned(
                  left: 20,
                  bottom: 4,
                  child: Transform.rotate(
                    angle: -0.4,
                    child: Icon(
                      Icons.eco,
                      color: const Color(0xFFE8F5E9).withOpacity(0.22),
                      size: 26,
                    ),
                  ),
                ),
                // Decorative Leaf Icon 2 (Bottom Right)
                Positioned(
                  right: 50,
                  bottom: 8,
                  child: Transform.rotate(
                    angle: 0.6,
                    child: Icon(
                      Icons.spa,
                      color: const Color(0xFFE8F5E9).withOpacity(0.18),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),

            // 4. MAIN PROMO SLIDER CAROUSEL (Poster banner matching mockup)
            Container(
              child: AspectRatio(
                aspectRatio: 2.0, // Matches the exact 2:1 aspect ratio of the uploaded banners
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    setState(() {
                      _activeSliderIndex = idx;
                    });
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GestureDetector(
                          onTap: () {
                            appState.openCategoryScreen(
                              categoryName: 'Vegetables',
                            );
                          },
                          child: Image.asset(
                            'assets/images/home_banner_1.jpg',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GestureDetector(
                          onTap: () {
                            appState.openCategoryScreen(
                              categoryName: 'Dairy',
                            );
                          },
                          child: Image.asset(
                            'assets/images/home_banner_2.jpg',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GestureDetector(
                          onTap: () {
                            appState.openCategoryScreen(
                              categoryName: 'Fruits',
                            );
                          },
                          child: Image.asset(
                            'assets/images/home_banner_3.jpg',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  height: 6,
                  width: _activeSliderIndex == index ? 16 : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _activeSliderIndex == index
                        ? const Color(0xFF2E7D32)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            // 5. HORIZONTAL Highlights promo list
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildHighlightCard(
                    icon: Icons.percent_outlined,
                    iconColor: const Color(0xFF2E7D32),
                    bgColor: const Color(0xFFF4FBF4),
                    title: '50% OFF',
                    subtitle: 'On First Order',
                  ),
                  _buildHighlightCard(
                    icon: Icons.motorcycle_outlined,
                    iconColor: Colors.deepPurple,
                    bgColor: const Color(0xFFF8F5FB),
                    title: 'FREE DELIVERY',
                    subtitle: 'On orders above ₹199',
                  ),
                  _buildHighlightCard(
                    icon: Icons.currency_rupee_outlined,
                    iconColor: Colors.orange.shade700,
                    bgColor: const Color(0xFFFDFBF5),
                    title: '₹100 OFF',
                    subtitle: 'Use Code FLASH100',
                  ),
                  _buildHighlightCard(
                    icon: Icons.eco_outlined,
                    iconColor: const Color(0xFF2E7D32),
                    bgColor: const Color(0xFFF4FBF4),
                    title: '100% ORGANIC',
                    subtitle: 'Farm Fresh',
                    onTap: () {
                      appState.openCategoryScreen(
                        categoryName: 'Vegetables',
                        organicOnly: true,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // 6. SHOP BY CATEGORY HEADER + CIRCLES ROW
            _buildSectionHeader(
              title: 'Shop by Category',
              onSeeAll: () => appState.setNavIndex(1),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: appState.subCategories.length,
                itemBuilder: (context, index) {
                  final subCat = appState.subCategories[index];
                  String displayCategoryName = 'Vegetables';
                  if (subCat.categoryId == 'vegetables') displayCategoryName = 'Vegetables';
                  else if (subCat.categoryId == 'fruits') displayCategoryName = 'Fruits';
                  else if (subCat.categoryId == 'dairy') displayCategoryName = 'Dairy';
                  else if (subCat.categoryId == 'bakery') displayCategoryName = 'Bakery';
                  else if (subCat.categoryId == 'snacks') displayCategoryName = 'Snacks';
                  else if (subCat.categoryId == 'beverages') displayCategoryName = 'Beverages';

                  return _buildCategoryCircle(
                    title: subCat.name,
                    image: subCat.imageUrl,
                    onTap: () {
                      appState.setSelectedCategoryByName(displayCategoryName);
                      appState.setNavIndex(1);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // 7. BEST SELLERS
            if (bestSellers.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Best Sellers',
                onSeeAll: () {
                  appState.openCategoryScreen(
                    categoryName: 'Vegetables',
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 175,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bestSellers.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildProductCarouselCard(
                      context,
                      appState,
                      bestSellers[index],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 7.5. ORGANIC VEGETABLES
            if (organicVegetables.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Organic Vegetables',
                onSeeAll: () {
                  appState.openCategoryScreen(
                    categoryName: 'Vegetables',
                    organicOnly: true,
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 175,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: organicVegetables.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildProductCarouselCard(
                      context,
                      appState,
                      organicVegetables[index],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 8. NEW LAUNCH
            if (newLaunchProducts.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'New Launch',
                onSeeAll: () {
                  appState.setNavIndex(1);
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 175,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: newLaunchProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildProductCarouselCard(
                      context,
                      appState,
                      newLaunchProducts[index],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],



            // 9. REFER & EARN
            if (!appState.hasClaimedReferralReward) ...[
              _buildReferAndEarnCard(appState),
              const SizedBox(height: 20),
            ],
            // Bottom clearance for floating bottom navigation bar and mini cart
            SizedBox(height: appState.cartCount > 0 ? 76 : 16),
          ],
        ),
      ),
    ),
    if (appState.cartCount > 0)
      Positioned(
        left: 16,
        right: 16,
        bottom: 8,
        child: InkWell(
          onTap: () {
            appState.setNavIndex(2); // Instantly switch to Cart tab
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${appState.cartCount} items | ₹${appState.cartSubtotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text(
                      'View Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);
}

  Widget _buildSliderCard({
    required String badge,
    required String title,
    required String desc,
    required String buttonText,
    required Color buttonColor,
    required Color bgColor,
    required String assetName,
    Gradient? gradient,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            top: 0,
            width: 140,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
              child: Image.asset(
                assetName,
                fit: BoxFit.contain,
                color: bgColor,
                colorBlendMode: BlendMode.multiply,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.eco, size: 60, color: AppColors.primary),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            right: 130,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Text(
                      badge.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: onPressed ?? () {
                      Provider.of<AppState>(context, listen: false).openCategoryScreen(
                        categoryName: 'Vegetables',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(70, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          buttonText,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    required VoidCallback onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See All',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown(Product product, AppState appState) {
    if (!appState.hasProductVariants(product)) {
      return Text(
        product.unit,
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.textLight,
        ),
      );
    }

    final selectedUnit = appState.getProductSelectedUnit(product);
    final unitOptions = appState.getProductUnitOptions(product);

    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 0.6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: unitOptions.contains(selectedUnit) ? selectedUnit : (unitOptions.isNotEmpty ? unitOptions.first : selectedUnit),
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 11, color: AppColors.textLight),
          style: const TextStyle(fontSize: 8.5, color: AppColors.textDark, fontWeight: FontWeight.w600),
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

  Widget _buildProductCarouselCard(
    BuildContext context,
    AppState appState,
    Product product,
  ) {
    final String activeUnit = appState.getProductSelectedUnit(product);
    final int cartQty = appState.getProductQuantity(product.id, selectedUnit: activeUnit);
    final bool inStock = appState.isProductInStock(product.id);
    final prices = appState.getProductPriceForUnit(product, activeUnit);
    final double activePrice = prices['price']!;
    final double activeOriginalPrice = prices['originalPrice']!;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Opacity(
        opacity: inStock ? 1.0 : 0.55,
        child: Container(
          width: 114,
          decoration: BoxDecoration(
            color: inStock ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: inStock ? Colors.grey.shade100 : Colors.grey.shade300, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Product Image & Badges
            Expanded(
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2, left: 2, right: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FBF9),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Center(
                      child: ProductImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover, // WIDE AND COVER
                      ),
                    ),
                  ),
                  // Top-Left Discount Badge
                  if (product.originalPrice > product.price)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          '${product.discountPercent}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  // Top-Right Favorite Heart Icon
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        appState.toggleFavorite(product.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 2),
                          ],
                        ),
                        child: Icon(
                          appState.isFavorite(product.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: appState.isFavorite(product.id)
                              ? Colors.red
                              : Colors.grey.shade400,
                          size: 11,
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
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 7.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Text Info Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  _buildUnitDropdown(product, appState),
                  const SizedBox(height: 3),
                  // Price row with trailing add button on the right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cartQty > 1
                                    ? '₹${(activePrice * cartQty).toStringAsFixed(0)}'
                                    : '₹${activePrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.5,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (cartQty > 1)
                                Text(
                                  '(${cartQty}x₹${activePrice.toStringAsFixed(0)})',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else if (activeOriginalPrice > activePrice)
                                Text(
                                  '₹${activeOriginalPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 8.5,
                                    color: AppColors.textLight,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Add / Quantity buttons
                      !appState.isProductInStock(product.id)
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300, width: 0.8),
                              ),
                              child: Text(
                                'SOLD OUT',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            )
                          : cartQty == 0
                              ? GestureDetector(
                                  onTap: () => appState.addToCart(
                                    product,
                                    selectedUnit: activeUnit,
                                    price: activePrice,
                                    originalPrice: activeOriginalPrice,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.add, color: Colors.white, size: 12),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => appState.removeFromCart(product, selectedUnit: activeUnit),
                                        child: const Icon(Icons.remove, color: Colors.white, size: 10),
                                      ),
                                      const SizedBox(width: 2),
                                      GestureDetector(
                                        onTap: () => _showQuantitySelector(context, appState, product, cartQty),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$cartQty',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9.5,
                                              ),
                                            ),
                                            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 10),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      GestureDetector(
                                        onTap: () => appState.addToCart(
                                          product,
                                          selectedUnit: activeUnit,
                                          price: activePrice,
                                          originalPrice: activeOriginalPrice,
                                        ),
                                        child: const Icon(Icons.add, color: Colors.white, size: 10),
                                      ),
                                    ],
                                  ),
                                ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildCategoryPill({
    required String title,
    IconData? icon,
    String? image,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final bgColor = isActive ? const Color(0xFFE8F5E9) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: isActive ? const Color(0xFFC8E6C9) : Colors.grey.shade100,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Larger image/icon
            if (icon != null)
              Icon(icon, color: isActive ? const Color(0xFF2E7D32) : Colors.grey.shade600, size: 22)
            else if (image != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.0),
                  child: () {
                    final String resolved = ProductImage.getLocalAssetOrUrl(image);
                    if (resolved.startsWith('assets/')) {
                      return Image.asset(
                        resolved,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        color: bgColor,
                        colorBlendMode: BlendMode.multiply,
                        cacheWidth: 80,
                        cacheHeight: 80,
                        errorBuilder: (c, e, s) => const Icon(Icons.eco, size: 22),
                      );
                    } else {
                      return CachedNetworkImage(
                        imageUrl: resolved,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        color: bgColor,
                        colorBlendMode: BlendMode.multiply,
                        fadeInDuration: const Duration(milliseconds: 50),
                        fadeOutDuration: const Duration(milliseconds: 50),
                        placeholder: (context, url) => Container(width: 32, height: 32, color: Colors.transparent),
                        errorWidget: (c, u, e) => const Icon(Icons.eco, size: 22),
                      );
                    }
                  }(),
                ),
              ),
            const SizedBox(height: 1),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF2E7D32) : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 98, // Shorter in length
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: iconColor.withOpacity(0.15), width: 1), // Enhanced border look
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 7.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCircle({
    required String title,
    required String image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        width: 58,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC8E6C9), width: 1.5),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: () {
                  final String resolved = ProductImage.getLocalAssetOrUrl(image);
                  if (resolved.startsWith('assets/')) {
                    return Image.asset(
                      resolved,
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                      cacheHeight: 120,
                      errorBuilder: (c, e, s) => const Icon(Icons.eco, color: Color(0xFF2E7D32), size: 18),
                    );
                  } else {
                    return CachedNetworkImage(
                      imageUrl: resolved,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 50),
                      fadeOutDuration: const Duration(milliseconds: 50),
                      placeholder: (context, url) => Container(color: const Color(0xFFE8F5E9)),
                      errorWidget: (c, u, e) => const Icon(Icons.eco, color: Color(0xFF2E7D32), size: 18),
                    );
                  }
                }(),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferAndEarnCard(AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F8E9), Color(0xFFE8F5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.card_giftcard, color: Color(0xFF2E7D32), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REFER & EARN',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32), letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Get ₹100 Wallet Cash!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  'Share with friends and earn rewards',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showReferralShareSheet(context, appState),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: const Color(0xFF2E7D32).withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Refer Now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReferralShareSheet(BuildContext context, AppState appState) {
    if (!appState.hasClaimedReferralReward) {
      appState.claimReferralReward();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 ₹100 Wallet Cash added to your Sabzee Wallet!"),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 3),
        ),
      );
    }

    final String messageText = Uri.encodeComponent(
        "Hey! Use my code to sign up on Sabzee and get ₹100 instant cash directly in your wallet to buy fresh groceries! Download now: https://sabzee.page.link/refer");

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                    "Share Referral Link",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "You have earned ₹100 Wallet Cash! Share this code with friends so they can earn ₹100 too.",
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text("Share on WhatsApp"),
                onPressed: () async {
                  Navigator.pop(context);
                  final Uri whatsappUrl = Uri.parse("https://wa.me/?text=$messageText");
                  try {
                    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    final Uri waWeb = Uri.parse("https://api.whatsapp.com/send?text=$messageText");
                    try {
                      await launchUrl(waWeb, mode: LaunchMode.externalApplication);
                    } catch (err) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Could not open WhatsApp.")),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.message_outlined, size: 18),
                label: const Text("Share via SMS / Text"),
                onPressed: () async {
                  Navigator.pop(context);
                  final Uri smsUrl = Uri.parse("sms:?body=$messageText");
                  try {
                    await launchUrl(smsUrl);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not open SMS app directly.")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                label: const Text("Copy Referral Message", style: TextStyle(color: AppColors.primary)),
                onPressed: () {
                  Navigator.pop(context);
                  Clipboard.setData(const ClipboardData(text: "Hey! Use my code to sign up on Sabzee and get ₹100 instant cash directly in your wallet to buy fresh groceries! Download now: https://sabzee.page.link/refer"));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Referral message copied to clipboard!"),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuantitySelector(BuildContext context, AppState appState, Product product, int currentQty) {
    final int maxLimit = appState.getMaxLimitForProduct(product);
    final String activeUnit = appState.getProductSelectedUnit(product);
    final prices = appState.getProductPriceForUnit(product, activeUnit);
    final double unitPrice = prices['price']!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Quantity for ${product.name}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                "Maximum order limit: $maxLimit packs ($activeUnit each)",
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: maxLimit,
                  itemBuilder: (context, index) {
                    final int qty = index + 1;
                    final bool isSelected = qty == currentQty;
                    final double qtyPrice = unitPrice * qty;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      title: Text(
                        "$qty pack${qty > 1 ? 's' : ''}  •  ₹${qtyPrice.toStringAsFixed(0)}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textDark,
                          fontSize: 15,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary, size: 18) : null,
                      onTap: () {
                        appState.setProductQuantity(product, qty, selectedUnit: activeUnit);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FlippableCategoryCard extends StatefulWidget {
  final String name;
  final String imageUrl;
  final Color bg;
  final VoidCallback onTap;

  const FlippableCategoryCard({
    Key? key,
    required this.name,
    required this.imageUrl,
    required this.bg,
    required this.onTap,
  }) : super(key: key);

  @override
  _FlippableCategoryCardState createState() => _FlippableCategoryCardState();
}

class _FlippableCategoryCardState extends State<FlippableCategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _flipTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: math.pi,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    final randomDelay = math.Random().nextInt(2000) + 3000;
    _flipTimer = Timer.periodic(Duration(milliseconds: randomDelay), (timer) {
      if (!mounted) return;
      if (_controller.isDismissed) {
        _controller.forward();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _controller.reverse();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _flipTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value;
          final isBack = angle >= math.pi / 2;
          final transformAngle = isBack ? angle - math.pi : angle;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(transformAngle),
            alignment: Alignment.center,
            child: isBack ? _buildBackCard() : _buildFrontCard(),
          );
        },
      ),
    );
  }

  Widget _buildFrontCard() {
    return Container(
      height: 72,
      width: 72,
      decoration: BoxDecoration(
        color: widget.bg.withOpacity(0.4),
        shape: BoxShape.circle,
        border: Border.all(color: widget.bg.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: widget.bg.withOpacity(0.35),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: ClipOval(
        child: () {
          final String resolved = ProductImage.getLocalAssetOrUrl(widget.imageUrl);
          if (resolved.startsWith('assets/')) {
            return Image.asset(
              resolved,
              fit: BoxFit.cover,
              cacheWidth: 144,
              cacheHeight: 144,
            );
          } else {
            return CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.cover,
              maxWidthDiskCache: 144,
              maxHeightDiskCache: 144,
              fadeInDuration: const Duration(milliseconds: 50),
              fadeOutDuration: const Duration(milliseconds: 50),
              placeholder: (context, url) => Container(color: widget.bg.withOpacity(0.08)),
              errorWidget: (context, url, error) => Container(
                color: widget.bg.withOpacity(0.2),
                child: Icon(Icons.eco_outlined, color: widget.bg, size: 28),
              ),
            );
          }
        }(),
      ),
    );
  }

  Widget _buildBackCard() {
    return Container(
      height: 72,
      width: 72,
      decoration: BoxDecoration(
        color: widget.bg,
        shape: BoxShape.circle,
        border: Border.all(color: widget.bg.withOpacity(0.9), width: 2),
        boxShadow: [
          BoxShadow(
            color: widget.bg.withOpacity(0.45),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        widget.name,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: widget.bg.computeLuminance() > 0.5
              ? Colors.black87
              : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class FlippablePromoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final Color textColor;

  const FlippablePromoCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.textColor,
  }) : super(key: key);

  @override
  _FlippablePromoCardState createState() => _FlippablePromoCardState();
}

class _FlippablePromoCardState extends State<FlippablePromoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _flipTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: math.pi,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    final randomDelay = math.Random().nextInt(2000) + 4000;
    _flipTimer = Timer.periodic(Duration(milliseconds: randomDelay), (timer) {
      if (!mounted) return;
      if (_controller.isDismissed) {
        _controller.forward();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _controller.reverse();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _flipTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value;
        final isBack = angle >= math.pi / 2;
        final transformAngle = isBack ? angle - math.pi : angle;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(transformAngle),
          alignment: Alignment.center,
          child: isBack ? _buildBackCard() : _buildFrontCard(),
        );
      },
    );
  }

  Widget _buildFrontCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.textColor.withOpacity(0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.textColor.withOpacity(0.12),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 12, color: widget.textColor),
          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 16,
            color: widget.textColor.withOpacity(0.2),
          ),
          const SizedBox(width: 4),
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: widget.textColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.textColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: widget.textColor.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Container(width: 1, height: 16, color: Colors.white.withOpacity(0.3)),
          const SizedBox(width: 4),
          Text(
            widget.desc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 15); // Deeper curve
    
    // Tight curvy wave shape at bottom
    var firstControlPoint = Offset(size.width * 0.25, size.height - 30);
    var firstEndPoint = Offset(size.width * 0.5, size.height - 14);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    
    var secondControlPoint = Offset(size.width * 0.75, size.height + 4);
    var secondEndPoint = Offset(size.width, size.height - 10);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );
    
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HeaderWaveClipperBorder extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 10); // Shifted 5px lower
    
    var firstControlPoint = Offset(size.width * 0.25, size.height - 25);
    var firstEndPoint = Offset(size.width * 0.5, size.height - 9);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    
    var secondControlPoint = Offset(size.width * 0.75, size.height + 9);
    var secondEndPoint = Offset(size.width, size.height - 5);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );
    
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
