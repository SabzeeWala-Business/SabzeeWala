import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

class InvoiceSheet {
  static void show(BuildContext context, Order order, AppState appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InvoiceBottomSheetContent(order: order, appState: appState),
    );
  }
}

class _InvoiceBottomSheetContent extends StatefulWidget {
  final Order order;
  final AppState appState;

  const _InvoiceBottomSheetContent({
    required this.order,
    required this.appState,
  });

  @override
  State<_InvoiceBottomSheetContent> createState() => _InvoiceBottomSheetContentState();
}

class _InvoiceBottomSheetContentState extends State<_InvoiceBottomSheetContent> {
  bool _isDownloading = false;

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }

  String _getCustomerName() {
    if (widget.order.customerName.isNotEmpty && widget.order.customerName != 'User Name') {
      return widget.order.customerName;
    }
    if (widget.appState.userName.isNotEmpty && widget.appState.userName != 'User Name') {
      return widget.appState.userName;
    }
    return 'Valued Customer';
  }

  String _getCustomerPhone() {
    if (widget.order.customerPhone.isNotEmpty) {
      return widget.order.customerPhone;
    }
    if (widget.appState.userMobile != null && widget.appState.userMobile!.isNotEmpty) {
      return widget.appState.userMobile!;
    }
    return 'N/A';
  }

  String _getDeliveryAddress() {
    if (widget.order.deliveryAddress.isNotEmpty) {
      return widget.order.deliveryAddress;
    }
    final sel = widget.appState.selectedAddress;
    if (sel != null && sel.addressLine.isNotEmpty) {
      return '${sel.addressLine}, ${sel.city} - ${sel.pinCode}';
    }
    if (widget.appState.userCurrentLocation.isNotEmpty) {
      return widget.appState.userCurrentLocation;
    }
    return 'Darbhanga, Bihar - 846004';
  }

  bool _isPaid() {
    final method = widget.order.paymentMethod.toUpperCase();
    final status = widget.order.paymentStatus.toLowerCase();
    return method == 'ONLINE' || status == 'paid';
  }

  Future<void> _downloadInvoice() async {
    setState(() => _isDownloading = true);

    final bool isPaid = _isPaid();
    final String paymentTag = isPaid ? 'PAID (Online - Cashfree / Card / UPI)' : 'CASH ON DELIVERY (Pay on delivery)';
    final String custName = _getCustomerName();
    final String custPhone = _getCustomerPhone();
    final String address = _getDeliveryAddress();
    final String dateStr = _formatDate(widget.order.date);

    final buffer = StringBuffer();
    buffer.writeln('==============================================');
    buffer.writeln('               SABZEEWALA                     ');
    buffer.writeln('       10-Minute Farm Fresh Grocery           ');
    buffer.writeln('       Tax Invoice / Bill of Supply           ');
    buffer.writeln('==============================================');
    buffer.writeln('Order ID      : #${widget.order.id}');
    buffer.writeln('Date & Time   : $dateStr');
    buffer.writeln('Customer Name : $custName');
    buffer.writeln('Phone Number  : $custPhone');
    buffer.writeln('Delivery To   : $address');
    buffer.writeln('Payment Mode  : $paymentTag');
    buffer.writeln('Order Status  : ${widget.order.status.toUpperCase()}');
    buffer.writeln('----------------------------------------------');
    buffer.writeln('ITEMS PURCHASED:');
    buffer.writeln('----------------------------------------------');

    for (final item in widget.order.items) {
      final unitStr = item.selectedUnit.isNotEmpty ? item.selectedUnit : item.product.unit;
      final line = '${item.product.name} ($unitStr) x ${item.quantity}';
      final price = '₹${(item.price * item.quantity).toStringAsFixed(0)}';
      buffer.writeln('${line.padRight(36)} $price');
    }

    final double itemsSubtotal = (widget.order.totalAmount - 2).clamp(0, 999999).toDouble();
    buffer.writeln('----------------------------------------------');
    buffer.writeln('${'Items Subtotal:'.padRight(36)} ₹${itemsSubtotal.toStringAsFixed(0)}');
    buffer.writeln('${'Handling Fee:'.padRight(36)} ₹2.00');
    buffer.writeln('${'Delivery Fee:'.padRight(36)} FREE');
    buffer.writeln('==============================================');
    buffer.writeln('${'TOTAL AMOUNT:'.padRight(36)} ₹${widget.order.totalAmount.toStringAsFixed(0)}');
    buffer.writeln('${'PAYMENT STATUS:'.padRight(36)} ${isPaid ? "PAID" : "COD"}');
    buffer.writeln('==============================================');
    buffer.writeln('Thank you for choosing SabzeeWala!');
    buffer.writeln('For support, contact support@sabzeewala.com');
    buffer.writeln('==============================================');

    final invoiceText = buffer.toString();

    // 1. Copy to Clipboard
    await Clipboard.setData(ClipboardData(text: invoiceText));

    // 2. Try saving to Android Download directory or app cache
    String saveMessage = 'Invoice copied to clipboard!';
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final file = File('${downloadDir.path}/SabzeeWala_Invoice_${widget.order.id}.txt');
        await file.writeAsString(invoiceText);
        saveMessage = 'Invoice saved to Downloads folder & copied to clipboard!';
      }
    } catch (_) {
      // Ignored if storage permission restricts file creation
    }

    if (mounted) {
      setState(() => _isDownloading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  saveMessage,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPaid = _isPaid();
    final String custName = _getCustomerName();
    final String custPhone = _getCustomerPhone();
    final String address = _getDeliveryAddress();
    final String dateStr = _formatDate(widget.order.date);
    final double itemsSubtotal = (widget.order.totalAmount - 2).clamp(0, 999999).toDouble();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Scrollable Invoice Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SABZEEWALA',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tax Invoice / Bill of Supply',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Payment Status Banner (PAID vs COD)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPaid ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPaid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                          color: isPaid ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPaid ? 'PAID ONLINE' : 'CASH ON DELIVERY',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: isPaid ? const Color(0xFF1B5E20) : const Color(0xFFBF360C),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPaid
                                    ? 'Payment verified successfully via Cashfree Gateway'
                                    : 'Please pay ₹${widget.order.totalAmount.toStringAsFixed(0)} to delivery partner upon delivery',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isPaid ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order & Customer Details Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Order ID', '#${widget.order.id}', isBold: true),
                        const SizedBox(height: 6),
                        _buildDetailRow('Date & Time', dateStr),
                        const Divider(height: 18),
                        _buildDetailRow('Customer Name', custName, isBold: true),
                        const SizedBox(height: 6),
                        _buildDetailRow('Phone Number', custPhone),
                        const SizedBox(height: 6),
                        _buildDetailRow('Delivery Address', address),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Itemized Produce List
                  const Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.order.items.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final item = widget.order.items[index];
                        final unit = item.selectedUnit.isNotEmpty ? item.selectedUnit : item.product.unit;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$unit × ${item.quantity}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bill Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Items Subtotal', '₹${itemsSubtotal.toStringAsFixed(0)}'),
                        const SizedBox(height: 6),
                        _buildSummaryRow('Product Handling Fee', '₹2.00'),
                        const SizedBox(height: 6),
                        _buildSummaryRow('Delivery Fee', 'FREE', isHighlight: true),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              '₹${widget.order.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Sticky Bottom Actions
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isDownloading ? null : _downloadInvoice,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        _isDownloading ? 'Saving Invoice...' : 'Download Invoice',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
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

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppColors.primary : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
