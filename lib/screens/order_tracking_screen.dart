import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/invoice_sheet.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Order? order;
  const OrderTrackingScreen({super.key, this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _trackerController;
  late Animation<Offset> _scooterAnimation;
  int _minsRemaining = 12;
  Timer? _countdownTimer;
  String _liveColony = "Sabzee Hub Colony";
  double _distanceKm = 1.6;

  void _loadLiveTrackingTelemetry() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _liveColony = place.subLocality ?? place.locality ?? "your location";
          _distanceKm = 1.1; 
        });
      }
    } catch (e) {
      debugPrint("Telemetry geocoding failed: $e. Using mock fallback.");
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLiveTrackingTelemetry();

    // Parse initial minutes remaining from the order deliveryTime string if available
    try {
      final orderTimeStr = widget.order?.deliveryTime ?? '';
      final match = RegExp(r'(\d+)').firstMatch(orderTimeStr);
      if (match != null) {
        _minsRemaining = int.parse(match.group(1)!);
      } else {
        _minsRemaining = 14; // default matching cart screen
      }
    } catch (_) {
      _minsRemaining = 14;
    }
    
    // 20-second looping animation representing delivery guy riding along roads
    _trackerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _scooterAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(30, 160), end: const Offset(120, 160)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(120, 160), end: const Offset(120, 70)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(120, 70), end: const Offset(270, 70)),
        weight: 30,
      ),
    ]).animate(_trackerController);

    // Countdown mock timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted && _minsRemaining > 2) {
        setState(() {
          _minsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _trackerController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final latestOrder = widget.order ?? (appState.orders.isNotEmpty ? appState.orders.first : null);
    final orderId = latestOrder?.id ?? "SW9828471";
    final String statusLower = latestOrder?.status.toLowerCase() ?? 'placed';
    final bool isOngoing = latestOrder == null || (statusLower != 'delivered' && statusLower != 'cancelled');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Track Order',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Order Status Top Banner
          Container(
            color: isOngoing
                ? const Color(0xFFF5FDF6)
                : statusLower == 'delivered'
                    ? const Color(0xFFF1F8E9)
                    : const Color(0xFFFFEBEE),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOngoing
                        ? const Color(0xFFE8F5E9)
                        : statusLower == 'delivered'
                            ? const Color(0xFFDCEDC8)
                            : const Color(0xFFFFCDD2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOngoing
                        ? Icons.delivery_dining
                        : statusLower == 'delivered'
                            ? Icons.task_alt
                            : Icons.cancel_outlined,
                    color: isOngoing
                        ? AppColors.primary
                        : statusLower == 'delivered'
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOngoing
                                ? (latestOrder?.deliveryTime.startsWith('Scheduled:') ?? false
                                    ? "Scheduled Delivery"
                                    : "Arriving in")
                                : statusLower == 'delivered'
                                    ? "Order Delivered"
                                    : "Order Cancelled",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          if (isOngoing)
                            Text(
                              (latestOrder?.deliveryTime.startsWith('Scheduled:') ?? false)
                                  ? latestOrder!.deliveryTime.replaceFirst('Scheduled: ', '')
                                  : "$_minsRemaining mins",
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Order #$orderId • ${latestOrder?.items.length ?? 0} items",
                        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // 2. LIVE VECTOR ROAD MAP CANVAS / SUMMARY BLOCK
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: isOngoing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Map (Fixed height)
                        Container(
                          height: 240,
                          color: const Color(0xFFF9FAF9),
                          child: Stack(
                            children: [
                              // Decorative grid background
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.04,
                                  child: GridPaper(
                                    color: Colors.green.shade900,
                                    interval: 40,
                                    subdivisions: 1,
                                  ),
                                ),
                              ),

                              // Custom Paint Road Path
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: MapPathPainter(),
                                ),
                              ),

                              // Store Marker (Storefront)
                              const Positioned(
                                left: 20,
                                top: 146,
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.white,
                                      child: Icon(Icons.storefront, color: AppColors.primary, size: 18),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Sabzee Hub",
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                    ),
                                  ],
                                ),
                              ),

                              // Customer Home Marker (Pin)
                              const Positioned(
                                left: 250,
                                top: 56,
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.orange,
                                      child: Icon(Icons.home, color: Colors.white, size: 18),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Your Home",
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                    ),
                                  ],
                                ),
                              ),

                              // Animated Delivery Scooter Rider
                              AnimatedBuilder(
                                animation: _scooterAnimation,
                                builder: (context, child) {
                                  final pos = _scooterAnimation.value;
                                  return Positioned(
                                    left: pos.dx,
                                    top: pos.dy - 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primary, width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.3),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.motorcycle,
                                        color: AppColors.primary,
                                        size: 16,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),

                        // List of items in ongoing order
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Items in this order:",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 10),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: latestOrder?.items.length ?? 0,
                                itemBuilder: (context, idx) {
                                  final item = latestOrder!.items[idx];
                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.grey.shade100),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.product.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                Text(
                                                  "${item.product.unit} x ${item.quantity}",
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            "₹${(item.product.price * item.quantity).toStringAsFixed(0)}",
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: const Color(0xFFF9FAF9),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Center(
                            child: Icon(
                              statusLower == 'delivered'
                                  ? Icons.verified_rounded
                                  : Icons.cancel_rounded,
                              size: 80,
                              color: statusLower == 'delivered'
                                  ? Colors.green
                                  : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              statusLower == 'delivered'
                                  ? "Delivered Successfully!"
                                  : "This order was Cancelled",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: statusLower == 'delivered'
                                      ? Colors.green.shade800
                                      : Colors.red.shade800),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              statusLower == 'delivered'
                                  ? "Your items were delivered on time."
                                  : "Refund has been initiated if paid online.",
                              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Items in this order:",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 10),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: latestOrder.items.length,
                            itemBuilder: (context, idx) {
                              final item = latestOrder.items[idx];
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.grey.shade100),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.product.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text(
                                              "${item.product.unit} x ${item.quantity}",
                                              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        "₹${(item.product.price * item.quantity).toStringAsFixed(0)}",
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // 3. STEP MILESTONE TRACKER & COURIER CARD / BOTTOM BUTTON
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isOngoing) ...[
                  // Milestone status row
                  Row(
                    children: [
                      _buildMilestoneStep("Placed", true),
                      _buildMilestoneDivider(true),
                      _buildMilestoneStep("Packing", true),
                      _buildMilestoneDivider(true),
                      _buildMilestoneStep("On the Way", true),
                      _buildMilestoneDivider(false),
                      _buildMilestoneStep("Arriving", false),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Delivery Executive Card details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(Icons.person, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Ramesh Kumar",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Rider is en route to ${appState.userCurrentLocation.isNotEmpty ? appState.userCurrentLocation.split(',').first : _liveColony} (${_distanceKm.toStringAsFixed(1)} km away)",
                                style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final Uri callUri = Uri.parse("tel:+919876543210");
                            try {
                              await launchUrl(callUri);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Calling Ramesh Kumar (+91 98765 43210)...")),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Icon(Icons.phone, color: AppColors.primary, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tax Invoice & Back to Home Action Buttons
                if (latestOrder != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => _showInvoiceSheet(context, latestOrder, appState),
                    icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                    label: const Text(
                      "View Official Tax Invoice",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Back to home button
                ElevatedButton(
                  onPressed: () {
                    Provider.of<AppState>(context, listen: false).setNavIndex(0);
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Back to Home",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceSheet(BuildContext context, Order order, AppState appState) {
    InvoiceSheet.show(context, order, appState);
  }

  Widget _buildMilestoneStep(String label, bool isDone) {
    return Column(
      children: [
        Icon(
          isDone ? Icons.check_circle : Icons.radio_button_off,
          color: isDone ? AppColors.primary : Colors.grey.shade300,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDone ? AppColors.textDark : AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneDivider(bool isDone) {
    return Expanded(
      child: Container(
        height: 3,
        color: isDone ? AppColors.primary : Colors.grey.shade200,
        margin: const EdgeInsets.only(bottom: 14),
      ),
    );
  }
}

class MapPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Road background
    final roadBgPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(48, 166)
      ..lineTo(138, 166)
      ..lineTo(138, 76)
      ..lineTo(288, 76);

    canvas.drawPath(path, roadBgPaint);

    // Active progress road layer
    final roadProgressPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.2)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, roadProgressPaint);

    // Dashed center line
    final dashPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final dashPath = Path()
      ..moveTo(48, 166)
      ..lineTo(138, 166)
      ..lineTo(138, 76)
      ..lineTo(288, 76);

    canvas.drawPath(dashPath, dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
