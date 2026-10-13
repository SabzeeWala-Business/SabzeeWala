import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import 'address_screen.dart';
import 'category_screen.dart';
import 'order_confirmation_screen.dart';
import '../services/supabase_service.dart';
import '../services/cashfree_service.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPaymentMethod = "cod";
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SupabaseService().updateUserActivity('checkout');
    CashfreeService().init();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<bool> _showExitCheckoutDialog(BuildContext context) async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "Leave Checkout?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to exit checkout?\n\nDon't worry, all items are saved in your cart and you can complete your order anytime.",
          style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textDark),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Stay on Checkout",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Yes, Leave",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  Future<bool> _showCancelPaymentDialog(BuildContext context) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 8),
            Text(
              "Discard Payment?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to cancel this payment transaction?\n\nYour order has not been placed yet, and all items will remain safely in your cart.",
          style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textDark),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Continue Payment",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Yes, Discard",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (shouldCancel == true && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final activeAddress = appState.selectedAddress;
    final double couponDiscount = appState.couponDiscount;
    final double finalPayTotal = appState.cartTotal;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool shouldExit = await _showExitCheckoutDialog(context);
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () async {
              final bool shouldExit = await _showExitCheckoutDialog(context);
              if (shouldExit && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: const Text(
            'Checkout',
            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textDark),
        ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Deliver to
                const Text(
                  'Deliver to',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                  const SizedBox(height: 8),
                  activeAddress == null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade200, width: 1.2),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "No Delivery Address Selected",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AddressScreen()),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text("Select or Add Address"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    activeAddress.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AddressScreen()),
                                      );
                                    },
                                    child: const Text(
                                      'Change',
                                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                activeAddress.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeAddress.addressLine,
                                style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4),
                              ),
                              Text(
                                '${activeAddress.city} - ${activeAddress.pinCode}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ),
                const SizedBox(height: 14),

                // Add More Items Card in Checkout
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CategoryScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Want to add more veggies or grocery?',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Explore full catalog & categories',
                                style: TextStyle(fontSize: 11, color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delivery Instructions',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _instructionsController,
                  decoration: InputDecoration(
                    hintText: 'E.g. Leave at gate, Ring bell, Call before arrival...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                ),
                const SizedBox(height: 20),

                // Offers & Coupons section
                const Text(
                  'Offers & Coupons',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Column(
                  children: appState.coupons.map((coupon) {
                    final discountVal = coupon.isFreeDelivery 
                        ? appState.deliveryFee 
                        : (coupon.discountPercent > 0 
                            ? (appState.cartSubtotal * coupon.discountPercent).roundToDouble() 
                            : coupon.discountAmount);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildCouponCard(
                        code: coupon.code,
                        title: coupon.title,
                        desc: coupon.desc,
                        minAmount: coupon.minAmount,
                        discountValue: discountVal,
                        currentSubtotal: appState.cartSubtotal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Wallet Cash Card
                if (appState.walletBalance > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pay with Sabzee Wallet',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Available balance: ₹${appState.walletBalance.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: appState.useWallet,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            appState.toggleUseWallet();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Order Summary block
                const Text(
                  'Order Summary',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Item Total', '₹${appState.cartSubtotal.toStringAsFixed(0)}'),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Delivery Fee', appState.isDeliveryFree ? 'FREE' : '₹${appState.deliveryFee.toStringAsFixed(0)}', isDiscount: appState.isDeliveryFree),
                      const SizedBox(height: 8),
                      if (appState.packagingFee > 0) ...[
                        _buildSummaryRow('Packaging Fee', appState.isHandlingFree ? 'FREE' : '₹${appState.packagingFee.toStringAsFixed(0)}', isDiscount: appState.isHandlingFree),
                        const SizedBox(height: 8),
                      ],
                      _buildSummaryRow('Product Handling', '₹${appState.handlingCharge.toStringAsFixed(0)}'),
                      if (couponDiscount > 0) ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow('Coupon Discount', '-₹${couponDiscount.toStringAsFixed(0)}', isDiscount: true),
                      ],
                      if (appState.walletDeduction > 0) ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow('Wallet Deduction', '-₹${appState.walletDeduction.toStringAsFixed(0)}', isDiscount: true),
                      ],
                      const Divider(height: 24, color: AppColors.border),
                      _buildSummaryRow('To Pay', '₹${finalPayTotal.toStringAsFixed(0)}', isTotal: true),
                      const SizedBox(height: 8),
                      // Saving badge
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Yay! You saved ₹${appState.totalSavings.toStringAsFixed(0)} on this order',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Methods
                const Text(
                  'Payment Methods',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      _buildPaymentRadioTile(
                        value: 'upi',
                        title: 'UPI',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _buildPaymentRadioTile(
                        value: 'card',
                        title: 'Credit / Debit Card',
                        icon: Icons.credit_card_outlined,
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _buildPaymentRadioTile(
                        value: 'cod',
                        title: 'Cash on Delivery',
                        icon: Icons.money_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Place Order Button
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: () async {
                  if (appState.cartItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Your cart is empty! Please add items to order."),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  // Enforce confirmed delivery address before checkout or gateway
                  final activeAddress = appState.selectedAddress ??
                      (appState.addresses.isNotEmpty ? appState.addresses.first : null);
                  if (activeAddress == null || activeAddress.addressLine.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select or add a delivery address to proceed."),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddressScreen()),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        );
                        
                        final String? validationError = await appState.validateCartAndCheckout();
                        
                        if (context.mounted) {
                          Navigator.pop(context); // Dismiss loading
                        }
                        
                        if (validationError != null) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                                  SizedBox(width: 8),
                                  Text("Item Unavailable", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                              content: Text(
                                validationError,
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text(
                                    "Update Cart",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        if (context.mounted) {
                          if (_selectedPaymentMethod == 'cod') {
                            appState.placeOrder(
                              _selectedPaymentMethod,
                              instructions: _instructionsController.text.trim(),
                              customAmount: finalPayTotal,
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const OrderConfirmationScreen()),
                            );
                          } else {
                            _showPaymentGateway(context, appState, finalPayTotal);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Place Order',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${finalPayTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal 
                ? AppColors.textDark 
                : (isDiscount ? AppColors.primary : AppColors.textLight),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.bold,
            color: isDiscount ? AppColors.primary : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRadioTile({
    required String value,
    required String title,
    required IconData icon,
  }) {
    final bool isSelected = _selectedPaymentMethod == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : AppColors.textLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard({
    required String code,
    required String title,
    required String desc,
    required double minAmount,
    required double discountValue,
    required double currentSubtotal,
  }) {
    final appState = Provider.of<AppState>(context);
    final bool isUnlocked = currentSubtotal >= minAmount;
    final bool isApplied = appState.appliedCouponCode == code;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isApplied ? AppColors.primaryLight : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isApplied 
              ? AppColors.primary 
              : AppColors.border.withOpacity(0.5), 
          width: isApplied ? 1.5 : 1
        ),
      ),
      child: InkWell(
        onTap: isUnlocked
            ? () {
                if (isApplied) {
                  appState.removeCoupon();
                } else {
                  appState.applyCoupon(code);
                }
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isUnlocked 
                      ? (isApplied ? AppColors.primary : AppColors.primary.withOpacity(0.1))
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isUnlocked ? AppColors.primary : Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isUnlocked
                        ? (isApplied ? Colors.white : AppColors.primary)
                        : Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isUnlocked ? AppColors.textDark : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: isUnlocked ? AppColors.textLight : Colors.grey.shade400,
                      ),
                    ),
                    if (!isUnlocked) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Add ₹${(minAmount - currentSubtotal).toStringAsFixed(0)} more to unlock',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isApplied ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                  child: Text(
                    isApplied ? 'Applied' : 'Apply',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isApplied ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentGateway(BuildContext context, AppState appState, double total) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool processing = false;
            String statusText = "Initializing secure connection...";

            void launchCashfreePayment([String? upiAppPackage]) async {
              setModalState(() {
                processing = true;
                statusText = upiAppPackage != null
                    ? "Opening UPI App..."
                    : "Connecting to Cashfree...";
              });

              final phone = appState.userMobile ?? '9999999999';
              final name = appState.userName.isNotEmpty ? appState.userName : 'Sabzee Customer';
              final orderId =
                  'SW${(DateTime.now().millisecondsSinceEpoch % 10000000000).toString().padLeft(10, '0')}';

              try {
                final sessionData = await CashfreeService().createOrderSession(
                  orderId: orderId,
                  orderAmount: total,
                  customerPhone: phone,
                  customerName: name,
                );

                final paymentSessionId = sessionData['paymentSessionId'] as String;
                final envStr = sessionData['environment'] as String? ?? 'SANDBOX';
                final environment = envStr == 'PRODUCTION'
                    ? CFEnvironment.PRODUCTION
                    : CFEnvironment.SANDBOX;

                setModalState(() {
                  statusText = _selectedPaymentMethod == 'upi'
                      ? "Launching UPI Payment..."
                      : "Opening Cashfree Secure Checkout...";
                });

                await CashfreeService().startCheckout(
                  orderId: orderId,
                  paymentSessionId: paymentSessionId,
                  environment: environment,
                  paymentMethod: _selectedPaymentMethod,
                  upiAppPackage: upiAppPackage,
                  onSuccess: (verifiedOrderId) {
                    debugPrint("[Cashfree Success] Verified Order ID: $verifiedOrderId");
                    if (!mounted) return;
                    setModalState(() {
                      statusText = "Payment Verified! Placing Order...";
                    });
                    appState.placeOrder(
                      _selectedPaymentMethod,
                      instructions: _instructionsController.text.trim(),
                      customAmount: total,
                      customOrderId: orderId,
                    );
                    Navigator.of(context, rootNavigator: true).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderConfirmationScreen(),
                      ),
                    );
                  },
                  onFailure: (message, failedOrderId) {
                    debugPrint("[Cashfree Failure]: $message");
                    if (!mounted) return;
                    
                    // Dismiss the payment bottom sheet modal
                    try {
                      Navigator.of(context, rootNavigator: true).pop();
                    } catch (_) {}

                    // Show dialog informing user order was not booked and cart is safe
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 26),
                            SizedBox(width: 8),
                            Text("Order Not Booked", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Your payment was cancelled or not completed. Your order was not placed.\n\nDon't worry, all items are still safely saved in your cart!",
                              style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textDark),
                            ),
                            if (message.isNotEmpty &&
                                !message.toLowerCase().contains('cancel') &&
                                !message.toLowerCase().contains('back')) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  message,
                                  style: TextStyle(fontSize: 11.5, color: Colors.red.shade900, height: 1.3),
                                ),
                              ),
                            ],
                          ],
                        ),
                        actions: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Review Cart & Try Again", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                );
              } catch (e) {
                debugPrint("[Cashfree Session Error]: $e");
                if (mounted && context.mounted) {
                  try {
                    Navigator.of(context, rootNavigator: true).pop();
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Payment gateway error: $e"),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }

            }

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                await _showCancelPaymentDialog(context);
              },
              child: Container(
                height: MediaQuery.of(context).size.height * 0.70,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: processing
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 5,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            statusText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Please do not close the app or press back button",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 28),
                          OutlinedButton.icon(
                            onPressed: () => _showCancelPaymentDialog(context),
                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.red.shade200, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            label: const Text(
                              "Cancel & Discard Payment",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "SECURE GATEWAY",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.lock, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          "CASHFREE PAYMENTS",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _showCancelPaymentDialog(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.red.shade200, width: 1.2),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.close_rounded, size: 16, color: Colors.red.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Cancel",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),
                          Container(
                            color: Colors.grey.shade50,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Order Total",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  "₹${total.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: _selectedPaymentMethod == 'upi'
                                  ? _buildUPIGatewayContent(launchCashfreePayment, total)
                                  : _buildCardGatewayContent(() => launchCashfreePayment(), total),
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUPIGatewayContent(Function([String?]) onPay, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Pay via UPI App",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 4),
        Text(
          "Tap your installed app to pay directly via UPI Intent:",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        _buildUPIAppTile(
          "Google Pay",
          "gpay",
          () => onPay("com.google.android.apps.nbu.paisa.user"),
        ),
        const SizedBox(height: 10),
        _buildUPIAppTile(
          "PhonePe",
          "phonepe",
          () => onPay("com.phonepe.app"),
        ),
        const SizedBox(height: 10),
        _buildUPIAppTile(
          "Paytm UPI",
          "paytm",
          () => onPay("net.one97.paytm"),
        ),
        const SizedBox(height: 10),
        _buildUPIAppTile(
          "Other UPI Apps (BHIM, CRED, etc.)",
          "other",
          () => onPay(null),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => onPay(null),
          icon: const Icon(Icons.flash_on, size: 18),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          label: Text(
            "Pay ₹${total.toStringAsFixed(0)} via Any UPI App",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showCancelPaymentDialog(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textDark),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            side: BorderSide(color: Colors.grey.shade300, width: 1.2),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          label: const Text(
            "Cancel & Choose Other Payment Method",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 14, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              "Direct UPI Intent • 256-Bit Encrypted & PCI-DSS Compliant",
              style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUPIAppTile(String name, String app, VoidCallback onTap) {
    Color iconColor;
    IconData iconData;
    String subtitle;
    if (app == 'gpay') {
      iconColor = const Color(0xFF1A73E8);
      iconData = Icons.account_balance_wallet_rounded;
      subtitle = 'Direct payment with Google Pay';
    } else if (app == 'phonepe') {
      iconColor = const Color(0xFF5F259F);
      iconData = Icons.flash_on_rounded;
      subtitle = 'Direct payment with PhonePe';
    } else if (app == 'paytm') {
      iconColor = const Color(0xFF002E6E);
      iconData = Icons.account_balance_rounded;
      subtitle = 'Direct payment with Paytm UPI';
    } else {
      iconColor = AppColors.primary;
      iconData = Icons.apps_rounded;
      subtitle = 'Choose from all installed UPI apps';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200, width: 1.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardGatewayContent(VoidCallback onPay, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Credit / Debit Card & NetBanking",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.credit_card, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    "Visa, Mastercard, RuPay & More",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "You will be redirected to the secure Cashfree checkout to enter card details and complete bank OTP authentication safely.",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onPay,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            "Proceed to Pay ₹${total.toStringAsFixed(0)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showCancelPaymentDialog(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textDark),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            side: BorderSide(color: Colors.grey.shade300, width: 1.2),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          label: const Text(
            "Cancel & Choose Other Payment Method",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 14, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              "RBI Tokenization & PCI-DSS Compliant",
              style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

}
