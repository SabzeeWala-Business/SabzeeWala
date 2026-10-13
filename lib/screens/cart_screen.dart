import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import 'address_screen.dart';
import 'checkout_screen.dart';
import 'category_screen.dart';
import 'favorites_screen.dart';
import 'coupon_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_selector_sheet.dart';
import '../services/supabase_service.dart';

class CartScreen extends StatelessWidget {
  final bool showBackButton;

  const CartScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    SupabaseService().updateUserActivity('cart');
    final cartItems = appState.cartItems;
    final selectedAddress = appState.selectedAddress;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 18),
          onPressed: () {
            if (showBackButton) {
              Navigator.pop(context);
            } else {
              Provider.of<AppState>(context, listen: false).setNavIndex(0);
            }
          },
        ),
        automaticallyImplyLeading: true,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddressScreen()),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedAddress != null ? selectedAddress.title : 'Choose Address',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black, size: 16),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                selectedAddress != null
                    ? selectedAddress.addressLine
                    : 'Add delivery address to check pricing',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoritesScreen()),
              );
            },
          ),
        ],
      ),
      body: cartItems.isEmpty
          ? _buildEmptyState(context, appState)
          : Column(
              children: [
                // Savings notification banner at the top
                if (appState.totalSavings > 0)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFE8F5E9),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Yay! You saved ',
                          style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '₹${appState.totalSavings.toStringAsFixed(0)}',
                          style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          ' on this order',
                          style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.green.shade800, size: 14),
                      ],
                    ),
                  ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await appState.refreshCatalog();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(14),
                      children: [
                      // 1. Coupons & Offers Card
                      _buildCouponsCard(context, appState),
                      const SizedBox(height: 14),

                      // 2. Delivery Time Estimator Card
                      _buildDeliveryTimeCard(context, cartItems.length, appState),
                      const SizedBox(height: 14),

                      // 3. Cart Items List Card
                      _buildCartItemsCard(context, cartItems, appState),
                      const SizedBox(height: 14),

                      // Add more items prompt
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CategoryScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.add_shopping_cart_rounded, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text(
                                  'Forgot something? ',
                                  style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'Add More Items',
                                  style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4. Bill Summary Card
                      _buildBillSummaryCard(appState),
                      const SizedBox(height: 14),

                      // 5. Savings Summary Card
                      if (appState.totalSavings > 0) _buildSavingsCard(appState),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

                // Sticky bottom pay button
                SafeArea(
                  top: false,
                  child: Container(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63), // Hot pink color matching mockup
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Click to Pay ₹${appState.cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState appState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F8E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_basket_outlined, size: 48, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add fresh vegetables & fruits to get started!',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                appState.setNavIndex(0); // Switch to Home tab
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Shop Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponsCard(BuildContext context, AppState appState) {
    final String? applied = appState.appliedCouponCode;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Blue Banner Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F0FE),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(4)),
                  child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Apply coupons + payment offers & save more',
                    style: TextStyle(color: Color(0xFF1A73E8), fontSize: 11, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Coupons row
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CouponScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF2E7D32), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              applied != null ? 'Coupon applied: $applied' : 'View coupons',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                            ),
                            if (applied != null)
                              Text(
                                'Saved extra ₹${appState.couponDiscount.toStringAsFixed(0)} on this order',
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      if (applied != null)
                        TextButton(
                          onPressed: () => appState.removeCoupon(),
                          child: const Text('Remove', style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      else
                        Icon(Icons.keyboard_arrow_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: DottedLinePainter(),
                ),
                const SizedBox(height: 12),

                // Payment Offers BHIM row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.orange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Flat ₹50 cashback with BHIM app',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.black),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CouponScreen()),
                              );
                            },
                            child: Row(
                              children: [
                                Text('View all payment offers', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500)),
                                Icon(Icons.keyboard_arrow_right_rounded, color: Colors.grey.shade600, size: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final bool isBHIMApplied = appState.appliedCouponCode == 'BHIM50';
                        return OutlinedButton(
                          onPressed: () {
                            if (isBHIMApplied) {
                              appState.removeCoupon();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('BHIM50 coupon removed!')),
                              );
                            } else {
                              if (appState.cartSubtotal >= 400) {
                                appState.applyCoupon('BHIM50');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('BHIM50 coupon applied! ₹50 saved.'),
                                    backgroundColor: Color(0xFF2E7D32),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Minimum order of ₹400 required for BHIM50.')),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isBHIMApplied ? const Color(0xFF2E7D32) : const Color(0xFFE91E63)),
                            backgroundColor: isBHIMApplied ? const Color(0xFFE8F5E9) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isBHIMApplied ? 'Applied' : 'Apply',
                            style: TextStyle(
                              color: isBHIMApplied ? const Color(0xFF2E7D32) : const Color(0xFFE91E63),
                              fontWeight: FontWeight.bold,
                              fontSize: 12
                            ),
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTimeCard(BuildContext context, int itemCount, AppState appState) {
    final bool isScheduled = appState.selectedDeliverySlot != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isScheduled ? Colors.green.shade200 : Colors.grey.shade200),
        boxShadow: isScheduled ? [
          BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))
        ] : null,
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: isScheduled ? Colors.green.shade50 : Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isScheduled ? Icons.calendar_today_rounded : Icons.timer_outlined, 
                color: isScheduled ? Colors.green.shade800 : Colors.green, 
                size: 20
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isScheduled ? 'Scheduled Delivery' : 'Delivering in 14 mins',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                ),
                const SizedBox(height: 2),
                Text(
                  isScheduled ? appState.selectedDeliverySlot! : '$itemCount items',
                  style: TextStyle(
                    color: isScheduled ? Colors.green.shade800 : Colors.grey.shade500, 
                    fontSize: 11.5, 
                    fontWeight: isScheduled ? FontWeight.bold : FontWeight.w500
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showScheduleBottomSheet(context, appState),
            icon: Icon(
              isScheduled ? Icons.check_circle_rounded : Icons.calendar_month_outlined, 
              color: isScheduled ? Colors.green : Colors.orange, 
              size: 14
            ),
            label: Text(
              isScheduled ? 'Scheduled' : 'Schedule', 
              style: TextStyle(
                color: isScheduled ? Colors.green.shade800 : Colors.black, 
                fontWeight: FontWeight.bold, 
                fontSize: 12
              )
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isScheduled ? Colors.green : Colors.orange),
              backgroundColor: isScheduled ? Colors.green.shade50 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleBottomSheet(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final now = DateTime.now();
        final dates = List.generate(3, (i) {
          final date = now.add(Duration(days: i));
          final weekday = i == 0 ? 'Today' : (i == 1 ? 'Tomorrow' : _getWeekdayName(date.weekday));
          final dateStr = "${date.day} ${_getMonthName(date.month)}";
          return {'label': '$weekday, $dateStr', 'dayLabel': weekday, 'dateVal': dateStr};
        });

        final List<String> slots = [
          '8:00 AM - 11:00 AM',
          '11:00 AM - 2:00 PM',
          '2:00 PM - 5:00 PM',
          '5:00 PM - 8:00 PM',
          '8:00 PM - 10:00 PM',
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            int selectedDateIndex = 0;
            int selectedSlotIndex = 0;

            if (appState.selectedDeliverySlot != null) {
              final parts = appState.selectedDeliverySlot!.split(', ');
              if (parts.length >= 2) {
                final dateLabel = parts[0];
                final slotLabel = parts[1];
                final dIdx = dates.indexWhere((d) => d['label'] == dateLabel);
                if (dIdx != -1) selectedDateIndex = dIdx;
                final sIdx = slots.indexOf(slotLabel);
                if (sIdx != -1) selectedSlotIndex = sIdx;
              }
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Delivery Slot',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(dates.length, (idx) {
                      final isSelected = selectedDateIndex == idx;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedDateIndex = idx;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  dates[idx]['dayLabel'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dates[idx]['dateVal'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected ? Colors.white70 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Time Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(slots.length, (idx) {
                      final isSelected = selectedSlotIndex == idx;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedSlotIndex = idx;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300),
                          ),
                          child: Text(
                            slots[idx],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF2E7D32) : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (appState.selectedDeliverySlot != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              appState.selectDeliverySlot(null);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Switched to Instant 14-min Delivery')),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Reset to Instant', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final String dateLabel = dates[selectedDateIndex]['label'] as String;
                            final String slotLabel = slots[selectedSlotIndex];
                            appState.selectDeliverySlot('$dateLabel, $slotLabel');
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Confirm Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getWeekdayName(int w) {
    switch (w) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  String _getMonthName(int m) {
    switch (m) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return '';
    }
  }

  Widget _buildCartItemsCard(BuildContext context, List<dynamic> cartItems, AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cartItems.length,
        separatorBuilder: (context, index) => CustomPaint(
          size: const Size(double.infinity, 1),
          painter: DottedLinePainter(),
        ),
        itemBuilder: (context, index) {
          final item = cartItems[index];
          final product = item.product;

          // Pricing variables
          final double activePrice = item.price * item.quantity;
          final double activeOriginalPrice = item.originalPrice * item.quantity;
          final bool hasDiscount = activeOriginalPrice > activePrice;

          return Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rounded image container
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBF9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ProductImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & weight details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.quantity > 1
                            ? '${item.selectedUnit} • ₹${item.price.toStringAsFixed(0)} each'
                            : item.selectedUnit,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Actions (plus/minus counter & pricing)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Pill counter box
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4EC), // Light pink color matching mockup
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF8BBD0)),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => appState.removeFromCart(product, selectedUnit: item.selectedUnit),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text('-', style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => showProductQuantitySelector(
                              context,
                              appState,
                              product,
                              item.quantity,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Color(0xFFE91E63), size: 14),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => appState.addToCart(
                              product,
                              selectedUnit: item.selectedUnit,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text('+', style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Prices crossed out
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasDiscount) ...[
                          Text(
                            '₹${activeOriginalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey.shade400,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '₹${activePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: hasDiscount ? const Color(0xFF2E7D32) : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillSummaryCard(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long_outlined, color: Colors.black, size: 16),
              SizedBox(width: 8),
              Text(
                'Bill Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Items original crossed out vs active prices
          _buildSummaryRow(
            'Item Total',
            appState.cartSubtotalOriginal,
            appState.cartSubtotal,
          ),
          const SizedBox(height: 8),

          _buildSummaryRow(
            'Delivery Fee',
            appState.deliveryFee,
            appState.activeDeliveryFee,
            isFreeText: appState.isDeliveryFree,
          ),
          const SizedBox(height: 8),

          if (appState.packagingFee > 0) ...[
            _buildSummaryRow(
              'Handling Fee',
              appState.packagingFee,
              appState.activeHandlingFee,
              isFreeText: appState.isHandlingFree,
            ),
            const SizedBox(height: 8),
          ],

          _buildSummaryRow(
            'Product Handling',
            appState.handlingCharge,
            appState.handlingCharge,
            isFreeText: false,
          ),

          if (appState.couponDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Coupon Discount',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                Text(
                  '-₹${appState.couponDiscount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: DottedLinePainter(),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'To Pay',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              Row(
                children: [
                  if (appState.cartSubtotalOriginal > appState.cartTotal) ...[
                    Text(
                      '₹${(appState.cartSubtotalOriginal + appState.deliveryFee + appState.handlingCharge).toStringAsFixed(0)}',
                      style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    '₹${appState.cartTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double original, double active, {bool isFreeText = false}) {
    final bool showOriginal = original > active;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            if (showOriginal) ...[
              Text(
                '₹${original.toStringAsFixed(0)}',
                style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (isFreeText && active == 0)
              const Text(
                'FREE',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              )
            else
              Text(
                '₹${active.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSavingsCard(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Savings on this order',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1B5E20)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '₹${appState.totalSavings.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSavingItem('Discount on MRP', appState.mrpDiscount, Icons.percent_rounded),
          if (appState.isDeliveryFree) ...[
            const SizedBox(height: 8),
            _buildSavingItem('FREE delivery savings', appState.deliveryFee, Icons.local_shipping_rounded),
          ],
          if (appState.isHandlingFree && appState.packagingFee > 0) ...[
            const SizedBox(height: 8),
            _buildSavingItem('Savings on Handling fee', appState.packagingFee, Icons.savings_outlined),
          ],
          if (appState.couponDiscount > 0) ...[
            const SizedBox(height: 8),
            _buildSavingItem('Savings from Coupon applied', appState.couponDiscount, Icons.confirmation_number_rounded),
          ],
        ],
      ),
    );
  }

  Widget _buildSavingItem(String label, double amount, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF1B5E20), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(color: Color(0xFF1B5E20), fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
