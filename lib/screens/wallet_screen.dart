import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import '../providers/app_state.dart';
import '../constants/colors.dart';
import '../services/cashfree_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    CashfreeService().init();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.fetchWalletData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _openPaymentModal(double amount) {
    if (amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter an amount of at least ₹1"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final rootNavigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        bool processing = false;
        String statusText = "Initializing secure connection...";

        return StatefulBuilder(
          builder: (builderContext, setModalState) {
            void launchCashfreePayment({String paymentMethod = 'upi', String? upiAppPackage}) async {
              setModalState(() {
                processing = true;
                statusText = upiAppPackage != null
                    ? "Opening UPI App..."
                    : paymentMethod == 'upi'
                        ? "Connecting to UPI..."
                        : "Connecting to Cashfree Gateway...";
              });

              final phone = appState.userMobile ?? '9999999999';
              final name = appState.userName.isNotEmpty ? appState.userName : 'Sabzee Customer';

              try {
                final sessionData = await CashfreeService().createWalletTopupSession(
                  orderAmount: amount,
                  customerPhone: phone,
                  customerName: name,
                );

                final paymentSessionId = sessionData['paymentSessionId'] as String;
                final orderId = sessionData['orderId'] as String;
                final envStr = sessionData['environment'] as String? ?? 'PRODUCTION';
                final environment = envStr == 'PRODUCTION'
                    ? CFEnvironment.PRODUCTION
                    : CFEnvironment.SANDBOX;

                setModalState(() {
                  statusText = paymentMethod == 'upi'
                      ? "Launching UPI Payment..."
                      : "Opening Cashfree Secure Checkout...";
                });

                await CashfreeService().startCheckout(
                  orderId: orderId,
                  paymentSessionId: paymentSessionId,
                  environment: environment,
                  paymentMethod: paymentMethod,
                  upiAppPackage: upiAppPackage,
                  onSuccess: (verifiedOrderId) async {
                    debugPrint("[Wallet Payment Success] Verified Order ID: $verifiedOrderId");
                    if (!mounted) return;

                    setModalState(() {
                      statusText = "Payment Verified! Crediting Wallet...";
                    });

                    final credited = await appState.creditWalletPayment(
                      orderId: verifiedOrderId,
                      amount: amount,
                    );

                    if (!mounted) return;
                    rootNavigator.pop();

                    _amountController.clear();
                    if (credited) {
                      _showSuccessDialog(amount, verifiedOrderId);
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text("Payment successful. Syncing wallet balance..."),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  onFailure: (message, failedOrderId) {
                    debugPrint("[Wallet Payment Failure]: $message");
                    if (!mounted) return;

                    try {
                      rootNavigator.pop();
                    } catch (_) {}

                    _showFailureDialog(message);
                  },
                );
              } catch (e) {
                debugPrint("[Wallet Cashfree Session Error]: $e");
                if (!mounted) return;

                setModalState(() {
                  processing = false;
                });

                messenger.showSnackBar(
                  SnackBar(
                    content: Text("Could not initiate payment: ${e.toString().replaceAll('Exception:', '').trim()}"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              child: processing
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
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
                            "Please do not close the app or press back",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "ADD MONEY TO WALLET",
                                    style: TextStyle(
                                      fontSize: 11,
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
                                        "CASHFREE SECURE PAYMENTS",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey),
                                onPressed: () => Navigator.pop(modalContext),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),

                        // Amount Banner
                        Container(
                          color: Colors.green.shade50.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Deposit Amount",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    "Instant credit to Sabzee Wallet",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "₹${amount.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),

                        // Options Body
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "Pay via UPI App",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Tap your favorite UPI app for 1-click payment:",
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 12),

                                // GPay
                                _buildPaymentTile(
                                  name: "Google Pay",
                                  subtitle: "Pay directly with Google Pay",
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: const Color(0xFF1A73E8),
                                  onTap: () => launchCashfreePayment(
                                    paymentMethod: 'upi',
                                    upiAppPackage: "com.google.android.apps.nbu.paisa.user",
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // PhonePe
                                _buildPaymentTile(
                                  name: "PhonePe",
                                  subtitle: "Pay directly with PhonePe",
                                  icon: Icons.flash_on_rounded,
                                  color: const Color(0xFF5F259F),
                                  onTap: () => launchCashfreePayment(
                                    paymentMethod: 'upi',
                                    upiAppPackage: "com.phonepe.app",
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Paytm
                                _buildPaymentTile(
                                  name: "Paytm UPI",
                                  subtitle: "Pay directly with Paytm",
                                  icon: Icons.account_balance_rounded,
                                  color: const Color(0xFF002E6E),
                                  onTap: () => launchCashfreePayment(
                                    paymentMethod: 'upi',
                                    upiAppPackage: "net.one97.paytm",
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Any UPI App
                                _buildPaymentTile(
                                  name: "Any UPI App (BHIM, CRED, WhatsApp)",
                                  subtitle: "Choose from all installed UPI apps",
                                  icon: Icons.apps_rounded,
                                  color: AppColors.primary,
                                  onTap: () => launchCashfreePayment(
                                    paymentMethod: 'upi',
                                    upiAppPackage: null,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Cards & NetBanking Divider
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey.shade300)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        "OR OTHER PAYMENT METHODS",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade500,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey.shade300)),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Cards & NetBanking
                                _buildPaymentTile(
                                  name: "Debit / Credit Card & NetBanking",
                                  subtitle: "Visa, Mastercard, RuPay & all major banks",
                                  icon: Icons.credit_card_rounded,
                                  color: Colors.teal.shade700,
                                  onTap: () => launchCashfreePayment(
                                    paymentMethod: 'web',
                                  ),
                                ),
                                const SizedBox(height: 18),

                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shield, size: 14, color: AppColors.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      "256-Bit SSL Encrypted • PCI-DSS Certified",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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

  Widget _buildPaymentTile({
    required String name,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200, width: 1.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
              const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(double amount, String orderId) {
    final appState = Provider.of<AppState>(context, listen: false);
    final shortId = orderId.length > 12 ? orderId.substring(orderId.length - 10) : orderId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Wallet Recharged! 🎉",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "₹${amount.toStringAsFixed(0)} has been credited to your Sabzee Wallet.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Updated Balance",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    "₹${appState.walletBalance.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ref ID: $shortId",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFailureDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text("Recharge Incomplete", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your payment was cancelled or could not be completed.\n\nDon't worry, no money was deducted from your account. You can retry anytime.",
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textDark),
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
                  style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Sabzee Wallet',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
          : RefreshIndicator(
              onRefresh: _loadWalletData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF15803D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sabzee Wallet Balance',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${appState.walletBalance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.shield_outlined, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        '100% Secure Payments via Cashfree',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Add Money Section
                      const Text(
                        'Add Money to Wallet',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: 'Enter amount to deposit (min ₹1)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Quick select chips
                            Row(
                              children: [100, 200, 500, 1000].map((amt) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                    child: OutlinedButton(
                                      onPressed: () {
                                        _amountController.text = amt.toString();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        side: const BorderSide(color: AppColors.primary),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '+₹$amt',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            ElevatedButton.icon(
                              onPressed: () {
                                final double val = double.tryParse(_amountController.text) ?? 0.0;
                                if (val < 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Please enter a valid amount (minimum ₹1)"),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                } else {
                                  _openPaymentModal(val);
                                }
                              },
                              icon: const Icon(Icons.account_balance_wallet, size: 18),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              label: const Text(
                                'Proceed to Add Cash',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Transactions List
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      appState.walletTransactions.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'No transaction logs found.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: appState.walletTransactions.length,
                              itemBuilder: (context, index) {
                                final tx = appState.walletTransactions[index];
                                final String type = tx['type']?.toString() ?? 'deposit';
                                final double amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                                final String desc = tx['description']?.toString() ?? 'Wallet Update';
                                final String rawDate = tx['created_at']?.toString() ?? '';

                                String dateFormatted = 'N/A';
                                if (rawDate.isNotEmpty) {
                                  try {
                                    dateFormatted = DateTime.parse(rawDate).toLocal().toString().split('.')[0];
                                  } catch (_) {}
                                }

                                final bool isCredit = amt >= 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade100),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isCredit ? Colors.green.shade50 : Colors.red.shade50,
                                      child: Icon(
                                        type == 'refund'
                                            ? Icons.replay
                                            : type == 'purchase'
                                                ? Icons.shopping_bag_outlined
                                                : Icons.add_circle_outline,
                                        color: isCredit ? Colors.green : Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      desc,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      dateFormatted,
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                    ),
                                    trailing: Text(
                                      '${isCredit ? "+" : ""}₹${amt.abs().toInt()}',
                                      style: TextStyle(
                                        color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
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
    );
  }
}
