import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  // Address Fields
  final TextEditingController _addressTitleController = TextEditingController();
  final TextEditingController _addressLineController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _pinCodeController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Prefill name and email if already present in AppState
    final appState = Provider.of<AppState>(context, listen: false);
    _nameController.text = appState.userName != 'User Name' ? appState.userName : '';
    _emailController.text = appState.userEmail != 'user@example.com' ? appState.userEmail : '';
    _addressTitleController.text = 'Home';
    _cityController.text = 'Darbhanga';
    _pinCodeController.text = '846004';
    
    // Fetch existing details/addresses on load
    _fetchExistingDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressTitleController.dispose();
    _addressLineController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pinCodeController.dispose();
    super.dispose();
  }

  void _fetchExistingDetails() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final mobile = appState.userMobile;
    if (mobile == null || mobile.isEmpty) return;

    // Check if appState already has synced address
    if (appState.addresses.isNotEmpty) {
      final addr = appState.addresses.firstWhere((a) => a.isSelected, orElse: () => appState.addresses.first);
      _prefillAddress(addr);
    } else {
      // Fetch from Supabase directly
      try {
        final addresses = await SupabaseService().getAddresses(mobile);
        if (addresses.isNotEmpty && mounted) {
          final addr = addresses.firstWhere((a) => a.isSelected, orElse: () => addresses.first);
          _prefillAddress(addr);
        }
      } catch (e) {
        print("Error fetching existing address: $e");
      }
    }
  }

  void _prefillAddress(Address addr) {
    setState(() {
      _addressTitleController.text = addr.title;
      _addressLineController.text = addr.addressLine;
      _landmarkController.text = addr.landmark;
      _cityController.text = addr.city;
      _pinCodeController.text = addr.pinCode;
      
      // If name is still empty, try to prefill from address
      if (_nameController.text.isEmpty && addr.fullName.isNotEmpty) {
        _nameController.text = addr.fullName;
      }
    });
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final addrTitle = _addressTitleController.text.trim();
      final addrLine = _addressLineController.text.trim();
      final landmark = _landmarkController.text.trim();
      final city = _cityController.text.trim();
      final pinCode = _pinCodeController.text.trim();
      
      final appState = Provider.of<AppState>(context, listen: false);
      final mobile = appState.userMobile ?? "";

      // Construct address object
      final newAddress = Address(
        id: appState.addresses.isNotEmpty 
            ? appState.addresses.first.id 
            : appState.generateUuid(),
        title: addrTitle.isNotEmpty ? addrTitle : 'Home',
        fullName: name,
        mobile: mobile,
        addressLine: addrLine,
        landmark: landmark,
        city: city.isNotEmpty ? city : 'Darbhanga',
        pinCode: pinCode.isNotEmpty ? pinCode : '846004',
        isSelected: true,
      );

      try {
        await appState.completeProfileAndSync(name, email);
        appState.addAddress(newAddress);
        
        if (mounted) {
          appState.setNavIndex(0); // Land on home screen tab
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile and Address updated successfully!"),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } catch (e) {
        print("Failed completing user profile: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Something went wrong. Please try again!"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final String userMobile = appState.userMobile ?? "";
    final String displayMobile = userMobile.startsWith('91') && userMobile.length == 12 
        ? userMobile.substring(2) 
        : userMobile;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Complete Your Profile",
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
            },
            child: const Text(
              "Skip",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      "Setting up your profile...",
                      style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w500),
                    )
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Icon & Text
                      const Center(
                        child: Icon(
                          Icons.account_circle_outlined,
                          size: 64,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          "Verify and complete your details to proceed",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section Title: Personal Details
                      const Text(
                        "Personal Details",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const Divider(height: 20),

                      // Full Name
                      const Text(
                        "Full Name *",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: "Enter full name",
                          hintStyle: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.person_outline, color: AppColors.textLight, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Full Name is required";
                          }
                          if (value.trim().length < 2) {
                            return "Name must be at least 2 characters";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Mobile Number (Read-only)
                      const Text(
                        "Mobile Number (Verified)",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textLight),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: displayMobile,
                        readOnly: true,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textLight),
                        decoration: InputDecoration(
                          fillColor: const Color(0xFFF9F9F9),
                          filled: true,
                          prefixIcon: const Icon(Icons.phone_iphone, color: AppColors.textLight, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Email Address
                      const Text(
                        "Email Address (Optional)",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: "Enter email address",
                          hintStyle: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.mail_outline, color: AppColors.textLight, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return "Please enter a valid email address";
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Section Title: Delivery Address
                      const Text(
                        "Delivery Address",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const Divider(height: 20),

                      // Address Type / Title
                      const Text(
                        "Address Type (e.g. Home, Work, Shop) *",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressTitleController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: "e.g. Home / Work / Other",
                          hintStyle: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.bookmark_outline, color: AppColors.textLight, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Address Type is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Address Line
                      const Text(
                        "Complete Address (House/Flat No., Road/Area) *",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressLineController,
                        keyboardType: TextInputType.streetAddress,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: "Enter complete address",
                          hintStyle: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.normal),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Icon(Icons.home_outlined, color: AppColors.textLight, size: 20),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Address Line is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Landmark
                      const Text(
                        "Landmark (Optional)",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _landmarkController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: "Near prominent place",
                          hintStyle: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.location_city_outlined, color: AppColors.textLight, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // City & Pin Code (Row)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "City *",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cityController,
                                  keyboardType: TextInputType.text,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "City is required";
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Pin Code *",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _pinCodeController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Pin Code is required";
                                    }
                                    if (value.trim().length != 6) {
                                      return "Should be 6 digits";
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0.5,
                        ),
                        child: const Text(
                          "Submit",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
