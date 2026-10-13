import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

import '../widgets/product_image.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
  int _activeTabIndex = 0; // 0 for Coupons, 1 for Payment Offers
  final Map<String, bool> _expandedState = {};

  void _showEnterCodeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Apply Promo Code', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Enter code (e.g. ARG10, FREE100)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final code = controller.text.trim().toUpperCase();
                if (code.isEmpty) return;

                final appState = Provider.of<AppState>(context, listen: false);
                final coupon = appState.coupons.firstWhere(
                  (c) => c.code == code,
                  orElse: () => CouponOffer(code: '', title: '', desc: '', minAmount: 0.0, imageUrl: ''),
                );

                if (coupon.code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid coupon code entered.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (appState.cartSubtotal < coupon.minAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Minimum order of ₹${coupon.minAmount.toStringAsFixed(0)} required for this coupon.',
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  appState.applyCoupon(code);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Coupon "$code" applied! Saved ₹${appState.couponDiscount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final subtotal = appState.cartSubtotal;
    final allActiveCoupons = appState.coupons.where((c) => c.status == 'active').toList();
    final featured = allActiveCoupons.where((c) => !c.isBrandAddon && c.code != 'BHIM50' && c.code != 'HDFC150').toList();
    final addons = allActiveCoupons.where((c) => c.isBrandAddon).toList();
    final effectiveFeatured = featured.isNotEmpty ? featured : allActiveCoupons;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14.0),
          child: Center(
            child: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 14),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: const Text(
          'Coupon & Offers',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: Center(
              child: OutlinedButton(
                onPressed: () => _showEnterCodeDialog(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Have a code?',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs control
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTabIndex = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _activeTabIndex == 0
                                  ? [
                                      const BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Coupons',
                              style: TextStyle(
                                color: _activeTabIndex == 0 ? Colors.black : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTabIndex = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _activeTabIndex == 1
                                  ? [
                                      const BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Payment Offers',
                              style: TextStyle(
                                color: _activeTabIndex == 1 ? Colors.black : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Note: You can now apply coupons and payment offers together.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // List content
          Expanded(
            child: _activeTabIndex == 0
                ? (allActiveCoupons.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_offer_outlined, size: 36, color: Color(0xFF2E7D32)),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No coupons available right now',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Check back soon! New promo codes will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        children: [
                          if (effectiveFeatured.isNotEmpty) ...[
                            const Text(
                              'FEATURED COUPONS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...effectiveFeatured.map((coupon) => _buildCouponCard(coupon, subtotal, appState)),
                            const SizedBox(height: 20),
                          ],
                          if (addons.isNotEmpty) ...[
                            const Text(
                              'AUTO-APPLIED BRAND ADD-ONS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...addons.map((coupon) => _buildCouponCard(coupon, subtotal, appState)),
                          ],
                        ],
                      ))
                : _buildPaymentOffersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(CouponOffer coupon, double subtotal, AppState appState) {
    final String code = coupon.code;
    final String title = coupon.title;
    final String desc = coupon.desc;
    final double minAmount = coupon.minAmount;
    final String? brandLogo = coupon.imageUrl;

    final bool isLocked = subtotal < minAmount;
    final bool isApplied = appState.appliedCouponCode == code;
    final bool isExpanded = _expandedState[code] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon / Logo
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: brandLogo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: () {
                            final String resolved = ProductImage.getLocalAssetOrUrl(brandLogo);
                            if (resolved.startsWith('assets/')) {
                              return Image.asset(resolved, fit: BoxFit.cover);
                            } else {
                              return CachedNetworkImage(
                                imageUrl: resolved,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.percent_rounded, color: Color(0xFF2E7D32), size: 18),
                              );
                            }
                          }(),
                        )
                      : const Center(
                          child: Icon(Icons.percent_rounded, color: Color(0xFF2E7D32), size: 18),
                        ),
                ),
                const SizedBox(width: 12),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                      ),
                      const SizedBox(height: 4),
                      if (isLocked)
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'Shop for ₹${(minAmount - subtotal).toStringAsFixed(0)} more to unlock',
                              style: const TextStyle(color: Colors.orange, fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        )
                      else
                        Text(
                          isApplied ? 'Coupon applied' : 'Unlocked! Ready to apply',
                          style: TextStyle(
                            color: isApplied ? const Color(0xFF2E7D32) : Colors.grey.shade500,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Locked / Apply button
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      'Locked',
                      style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 11.5),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      if (isApplied) {
                        appState.removeCoupon();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Coupon removed!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        appState.applyCoupon(code);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Coupon "$code" applied! Saved ₹${appState.couponDiscount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF2E7D32),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isApplied ? const Color(0xFFE8F5E9) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isApplied ? const Color(0xFF2E7D32) : const Color(0xFFE91E63)),
                      ),
                      child: Text(
                        isApplied ? 'Applied' : 'Apply',
                        style: TextStyle(
                          color: isApplied ? const Color(0xFF2E7D32) : const Color(0xFFE91E63),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Dotted Line
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: DottedLinePainter(),
          ),

          // Code & Know more
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expandedState[code] = !isExpanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isExpanded ? 'Show less' : 'Know more',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Text(
                desc,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentOffersList() {
    final appState = Provider.of<AppState>(context);
    final subtotal = appState.cartSubtotal;
    
    final paymentCoupons = appState.coupons.where((c) => c.code == 'BHIM50' || c.code == 'HDFC150').toList();
    
    if (paymentCoupons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 36, color: Colors.orange),
              ),
              const SizedBox(height: 16),
              const Text(
                'No payment offers available right now',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                'Check back soon for exciting bank & wallet cashback offers!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: paymentCoupons.length,
      itemBuilder: (context, index) {
        final coupon = paymentCoupons[index];
        final bool isLocked = subtotal < coupon.minAmount;
        final bool isApplied = appState.appliedCouponCode == coupon.code;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isApplied ? const Color(0xFF2E7D32) : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.account_balance_wallet_rounded, color: Colors.orange, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coupon.desc,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            coupon.code,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                          ),
                        ),
                        if (isApplied)
                          TextButton(
                            onPressed: () {
                              appState.removeCoupon();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Offer removed.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Text('Remove', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        else if (isLocked)
                          Text(
                            'Add ₹${(coupon.minAmount - subtotal).toStringAsFixed(0)} more',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                          )
                        else
                          ElevatedButton(
                            onPressed: () {
                              appState.applyCoupon(coupon.code);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('Applied! Saved ₹${appState.couponDiscount.toStringAsFixed(0)}'),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF2E7D32),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double dashWidth = 4;
    const double dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
