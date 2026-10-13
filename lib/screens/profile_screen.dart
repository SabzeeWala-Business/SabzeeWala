import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import 'orders_screen.dart';
import 'favorites_screen.dart';
import 'address_screen.dart';
import 'wallet_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatelessWidget {
  final bool showBackButton;
  const ProfileScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final userName = appState.userName;
    final userPhone = appState.userMobile ?? "9876543210";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 18),
          onPressed: () {
            if (showBackButton) {
              Navigator.pop(context);
            } else {
              Provider.of<AppState>(context, listen: false).setNavIndex(0);
            }
          },
        ),
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Info Header Card (Premium Member Card)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1B5E20), // Dark Green
                    Color(0xFF2E7D32), // Brand Green
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF2E7D32),
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // User Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+91 $userPhone',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showEditProfileDialog(context, appState),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.edit, size: 10, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (appState.profileStatus == 'incomplete')
              _buildIncompleteBanner(context, appState),
            
            // Personal Info & Address Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.015),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Account Details",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(Icons.sync_rounded, color: AppColors.primary.withOpacity(0.8), size: 16),
                    ],
                  ),
                  const Divider(height: 20),
                  
                  // Email Details
                  if (appState.userEmail.isNotEmpty && appState.userEmail != 'user@example.com') ...[
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            appState.userEmail,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Mobile Details
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        '+91 ${appState.userMobile != null && appState.userMobile!.startsWith('91') && appState.userMobile!.length == 12 ? appState.userMobile!.substring(2) : (appState.userMobile ?? "9876543210")}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Address Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            if (appState.addresses.isEmpty) {
                              return Text(
                                "No address added yet",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }
                            
                            final addr = appState.addresses.firstWhere(
                              (a) => a.isSelected,
                              orElse: () => appState.addresses.first,
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        addr.title.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const AddressScreen()),
                                        );
                                      },
                                      child: const Text(
                                        "Change / Edit",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  addr.addressLine,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                if (addr.landmark.isNotEmpty)
                                  Text(
                                    "Landmark: ${addr.landmark}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                Text(
                                  "${addr.city} - ${addr.pinCode}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Profile Options List as beautiful modern cards
            _buildOptionTile(
              icon: Icons.receipt_long_outlined,
              title: 'My Orders',
              iconColor: const Color(0xFF2E7D32),
              iconBgColor: const Color(0xFFE8F5E9),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OrdersScreen()),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Sabzee Wallet',
              iconColor: const Color(0xFF1E88E5),
              iconBgColor: const Color(0xFFE3F2FD),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WalletScreen()),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.favorite_border,
              title: 'My Favorites',
              iconColor: const Color(0xFFE91E63),
              iconBgColor: const Color(0xFFFCE4EC),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.confirmation_number_outlined,
              title: 'My Coupons',
              iconColor: const Color(0xFFFF9800),
              iconBgColor: const Color(0xFFFFF3E0),
              onTap: () => _showCouponsSheet(context),
            ),
            _buildOptionTile(
              icon: Icons.share_outlined,
              title: 'Refer & Earn',
              iconColor: const Color(0xFF9C27B0),
              iconBgColor: const Color(0xFFF3E5F5),
              onTap: () => _showReferEarnDialog(context),
            ),
            _buildOptionTile(
              icon: Icons.help_outline_outlined,
              title: 'Help & Support',
              iconColor: const Color(0xFF00ACC1),
              iconBgColor: const Color(0xFFE0F7FA),
              onTap: () => _showHelpSupportDialog(context),
            ),
            _buildOptionTile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              iconColor: const Color(0xFF607D8B),
              iconBgColor: const Color(0xFFECEFF1),
              onTap: () => _showSettingsDialog(context),
            ),
            _buildOptionTile(
              icon: Icons.logout,
              title: 'Logout',
              iconColor: const Color(0xFFD32F2F),
              iconBgColor: const Color(0xFFFFEBEE),
              titleColor: Colors.red.shade800,
              onTap: () {
                appState.logout();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
            SizedBox(height: showBackButton ? 32 : 100), // Clearance for floating dock
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? iconBgColor,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              children: [
                // Circular icon backdrop
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor ?? const Color(0xFFF1F8E9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: titleColor ?? AppColors.textDark,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AppState appState) {
    final nameController = TextEditingController(text: appState.userName == 'User Name' ? '' : appState.userName);
    final emailController = TextEditingController(text: appState.userEmail == 'user@example.com' ? '' : appState.userEmail);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? "Name cannot be empty" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email Address",
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Email cannot be empty";
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                      return "Enter a valid email address";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  appState.updateProfile(nameController.text.trim(), emailController.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profile updated successfully"), backgroundColor: AppColors.primary),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIncompleteBanner(BuildContext context, AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0B2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFB74D),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Profile Incomplete",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                ),
                const SizedBox(height: 2),
                Text(
                  "Complete your profile details to unlock all features.",
                  style: TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showEditProfileDialog(context, appState),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text("Complete", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  void _showCouponsSheet(BuildContext context) {
    final coupons = [
      {"code": "WELCOME50", "desc": "Get flat 50% off on your first order!"},
      {"code": "FRESH10", "desc": "Get flat 10% off on fresh vegetables and fruits."},
      {"code": "FREE299", "desc": "Get free delivery on orders above ₹299."}
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Available Coupons",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 16),
              ...coupons.map((coupon) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: const Color(0xFFF9FBF9),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  coupon["code"]!,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                coupon["desc"]!,
                                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Coupon code '${coupon["code"]}' copied!"),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          child: const Text("COPY", style: TextStyle(fontWeight: FontWeight.bold)),
                         ),
                       ],
                     ),
                   ),
                 );
               }).toList(),
             ],
           ),
         );
       },
     );
  }

  void _showReferEarnDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Refer & Earn", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard, size: 60, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                "Refer your friends and earn ₹100 inside Sabzee Coins for each referral!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textDark),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "SABZEE9876",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: AppColors.primary),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Referral code copied to clipboard!"), backgroundColor: AppColors.primary),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Referral link shared successfully!"), backgroundColor: AppColors.primary),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text("Share"),
            ),
          ],
        );
      },
    );
  }

  void _showHelpSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Help & Support", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone, color: AppColors.primary),
                title: const Text("Call Customer Support"),
                subtitle: const Text("+91 98765 43210"),
                onTap: () async {
                  Navigator.pop(context);
                  final Uri callUri = Uri.parse("tel:+919876543210");
                  try {
                    await launchUrl(callUri);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Calling customer support (+91 98765 43210)...")),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                title: const Text("WhatsApp Chat Support"),
                subtitle: const Text("Instant resolution"),
                onTap: () async {
                  Navigator.pop(context);
                  final Uri waUri = Uri.parse("https://wa.me/919876543210?text=Hello%20Sabzee%20Support%2C%20I%20need%20assistance.");
                  try {
                    await launchUrl(waUri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Could not launch WhatsApp.")),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                title: const Text("Email Support"),
                subtitle: const Text("support@sabzeewala.com"),
                onTap: () async {
                  Navigator.pop(context);
                  final Uri emailUri = Uri.parse("mailto:support@sabzeewala.com?subject=Customer%20Support%20Inquiry");
                  try {
                    await launchUrl(emailUri);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Opening email app...")),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context) {
    bool notifsEnabled = true;
    bool whatsappEnabled = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text("Push Notifications", style: TextStyle(fontSize: 14)),
                    activeColor: AppColors.primary,
                    value: notifsEnabled,
                    onChanged: (val) {
                      setState(() {
                        notifsEnabled = val;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("WhatsApp Updates", style: TextStyle(fontSize: 14)),
                    activeColor: AppColors.primary,
                    value: whatsappEnabled,
                    onChanged: (val) {
                      setState(() {
                        whatsappEnabled = val;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    title: Text("App Version", style: TextStyle(fontSize: 14)),
                    trailing: Text("v1.1.8", style: TextStyle(color: AppColors.textLight)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
