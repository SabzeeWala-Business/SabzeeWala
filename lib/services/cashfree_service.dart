import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupipayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupi.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import '../constants/app_env.dart';

typedef PaymentSuccessCallback = void Function(String orderId);
typedef PaymentFailureCallback = void Function(String message, String? orderId);

class CashfreeService {
  static final CashfreeService _instance = CashfreeService._internal();
  factory CashfreeService() => _instance;
  CashfreeService._internal();

  final CFPaymentGatewayService _cfPaymentGatewayService =
      CFPaymentGatewayService();

  bool _initialized = false;
  PaymentSuccessCallback? _onSuccess;
  PaymentFailureCallback? _onFailure;
  String? _activeOrderId;
  CFSession? _lastSession;

  /// Set to `false` for USB / Sideload testing (Sandbox mode)
  /// Set to `true` when publishing to Google Play Store
  static bool useProduction = AppEnv.cashfreeUseProduction;

  /// Your LIVE / PRODUCTION Credentials loaded from AppEnv (.env)
  static String liveAppId = AppEnv.cashfreeLiveAppId;
  static String liveSecretKey = AppEnv.cashfreeLiveSecretKey;

  /// SANDBOX Credentials for testing loaded from AppEnv (.env)
  static String sandboxAppId = AppEnv.cashfreeSandboxAppId;
  static String sandboxSecretKey = AppEnv.cashfreeSandboxSecretKey;

  /// Default backend base URL:
  /// - Use http://10.0.2.2:5000 for Android Emulator
  /// - Use http://192.168.x.x:5000 for physical phone on local Wi-Fi
  /// - Use your deployed server URL (e.g., https://api.sabzeewala.com) in production
  String backendBaseUrl = 'http://10.0.2.2:5000';

  void init() {
    if (_initialized) return;
    try {
      _cfPaymentGatewayService.setCallback(
        _verifyPaymentCallback,
        _onErrorCallback,
      );
      _initialized = true;
      debugPrint('[Cashfree] Service initialized with callbacks.');
    } catch (e) {
      debugPrint('[Cashfree Init Error]: $e');
    }
  }

  void _verifyPaymentCallback(String orderId) {
    debugPrint('[Cashfree] Payment verified for Order ID: $orderId');
    _onSuccess?.call(orderId);
  }

  void _onErrorCallback(CFErrorResponse errorResponse, String orderId) {
    debugPrint(
      '[Cashfree Error]: Code: ${errorResponse.getCode()}, Message: ${errorResponse.getMessage()}',
    );

    // If sideloaded/USB debug causes installer_package_not_approved, automatically fallback to Web Checkout
    if (errorResponse.getCode() == 'installer_package_not_approved' && _lastSession != null) {
      debugPrint('[Cashfree] Sideloaded APK detected. Auto-falling back to Cashfree Web Checkout...');
      try {
        final session = _lastSession!;
        _lastSession = null;
        final theme = CFThemeBuilder()
            .setNavigationBarBackgroundColorColor('#2E7D32')
            .setNavigationBarTextColor('#FFFFFF')
            .setButtonBackgroundColor('#2E7D32')
            .setButtonTextColor('#FFFFFF')
            .setPrimaryFont('Roboto')
            .setSecondaryFont('Roboto')
            .build();

        final payment = CFWebCheckoutPaymentBuilder()
            .setSession(session)
            .setTheme(theme)
            .build();

        _cfPaymentGatewayService.doPayment(payment);
        return;
      } catch (e) {
        debugPrint('[Cashfree Web Checkout Fallback Error]: $e');
      }
    }

    _onFailure?.call(
      errorResponse.getMessage() ?? 'Payment failed or cancelled',
      orderId.isNotEmpty ? orderId : _activeOrderId,
    );
  }

  /// Set this to your deployed cloud backend URL (e.g., https://api.sabzeewala.com)
  /// For local testing / Sandbox, it calls Cashfree HTTPS API directly for instant (<300ms) execution.
  String? cloudBackendUrl;

  /// Request payment session from Sabzee backend or direct Cashfree fallback
  Future<Map<String, dynamic>> createOrderSession({
    required String orderId,
    required double orderAmount,
    required String customerPhone,
    String? customerName,
    String? customerEmail,
    String? customBackendUrl,
  }) async {
    final String? activeBackend = customBackendUrl ?? cloudBackendUrl;

    // 1. If a live production cloud URL is provided (e.g. https://api.sabzeewala.com), use it:
    if (activeBackend != null &&
        activeBackend.startsWith('https://') &&
        !activeBackend.contains('localhost')) {
      try {
        final String url =
            '${activeBackend.replaceAll(RegExp(r'/+$'), '')}/api/cashfree/create-order';
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'orderId': orderId,
                'orderAmount': orderAmount,
                'customerPhone': customerPhone,
                'customerName': customerName ?? 'Sabzee Customer',
                'customerEmail': customerEmail ?? 'customer@sabzeewala.com',
              }),
            )
            .timeout(const Duration(seconds: 4));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          return {
            'paymentSessionId': data['paymentSessionId'] as String,
            'orderId': (data['orderId'] ?? orderId) as String,
            'environment': (data['environment'] ?? 'SANDBOX') as String,
          };
        }
      } catch (e) {
        debugPrint('[Cashfree] Cloud backend error: $e. Falling back to direct API.');
      }
    }

    // 2. Direct Cashfree Gateway Connection (Instant <300ms execution on ANY phone / network)
    final cleanPhone = customerPhone.replaceAll(RegExp(r'\D'), '');
    final phone10 = cleanPhone.length >= 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : '9999999999';

    final bool isLive = useProduction && liveAppId.isNotEmpty;
    final String activeAppId = isLive ? liveAppId : sandboxAppId;
    final String activeSecret = isLive ? liveSecretKey : sandboxSecretKey;

    if (activeAppId.isEmpty || activeSecret.isEmpty) {
      throw Exception(
        'Payment gateway keys not configured. Please pass .env file via --dart-define-from-file=.env',
      );
    }

    final String targetUrl = isLive
        ? 'https://api.cashfree.com/pg/orders'
        : 'https://sandbox.cashfree.com/pg/orders';
    final String activeEnv = isLive ? 'PRODUCTION' : 'SANDBOX';

    debugPrint('[Cashfree] Creating session on $activeEnv ($targetUrl)...');

    final directResponse = await http
        .post(
          Uri.parse(targetUrl),
          headers: {
            'x-client-id': activeAppId,
            'x-client-secret': activeSecret,
            'x-api-version': '2023-08-01',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'order_id': orderId,
            'order_amount': double.parse(orderAmount.toStringAsFixed(2)),
            'order_currency': 'INR',
            'customer_details': {
              'customer_id': 'CUST_$phone10',
              'customer_phone': phone10,
              'customer_name': customerName ?? 'Customer',
              'customer_email': customerEmail ?? 'customer@sabzeewala.com',
            },
            'order_meta': {
              'return_url':
                  'https://sabzeewala.com/payment-status?order_id=$orderId',
            },
          }),
        )
        .timeout(const Duration(seconds: 8));

    final directData = jsonDecode(directResponse.body);
    if (directResponse.statusCode == 200 &&
        directData['payment_session_id'] != null) {
      debugPrint(
        '[Cashfree] Session created in milliseconds: ${directData['payment_session_id']} (Env: $activeEnv)',
      );
      return {
        'paymentSessionId': directData['payment_session_id'] as String,
        'orderId': (directData['order_id'] ?? orderId) as String,
        'environment': activeEnv,
      };
    } else {
      throw Exception(
        directData['message'] ?? 'Failed to create Cashfree payment session',
      );
    }
  }

  /// Request payment session for wallet top-up from Sabzee backend or direct Cashfree fallback
  Future<Map<String, dynamic>> createWalletTopupSession({
    required double orderAmount,
    required String customerPhone,
    String? customerName,
    String? customerEmail,
    String? customBackendUrl,
  }) async {
    final cleanPhone = customerPhone.replaceAll(RegExp(r'\D'), '');
    final phone10 = cleanPhone.length >= 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : '9999999999';
    final orderId = 'WLT_${DateTime.now().millisecondsSinceEpoch}_${(100 + (DateTime.now().microsecondsSinceEpoch % 900))}';

    final String activeBackend = customBackendUrl ?? cloudBackendUrl ?? backendBaseUrl;

    // 1. Attempt Backend API (/api/wallet/create-order)
    if (activeBackend.isNotEmpty) {
      try {
        final String url = '${activeBackend.replaceAll(RegExp(r'/+$'), '')}/api/wallet/create-order';
        debugPrint('[Cashfree Wallet] Requesting session from backend: $url');
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'userId': customerPhone,
                'amount': orderAmount,
                'customerPhone': customerPhone,
                'customerName': customerName ?? 'Sabzee Customer',
                'customerEmail': customerEmail ?? 'customer@sabzeewala.com',
              }),
            )
            .timeout(const Duration(seconds: 4));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          debugPrint('[Cashfree Wallet] Backend session created: ${data['paymentSessionId']} (Env: ${data['environment']})');
          return {
            'paymentSessionId': data['paymentSessionId'] as String,
            'orderId': (data['orderId'] ?? orderId) as String,
            'environment': (data['environment'] ?? 'PRODUCTION') as String,
          };
        }
      } catch (e) {
        debugPrint('[Cashfree Wallet] Backend create-order error: $e. Falling back to direct Cashfree API.');
      }
    }

    // 2. Direct Cashfree Gateway Connection fallback
    return createOrderSession(
      orderId: orderId,
      orderAmount: orderAmount,
      customerPhone: phone10,
      customerName: customerName,
      customerEmail: customerEmail,
      customBackendUrl: customBackendUrl,
    );
  }

  /// Verify wallet payment with backend / Cashfree API
  Future<Map<String, dynamic>> verifyWalletPayment({
    required String orderId,
    required String userId,
    String? customBackendUrl,
  }) async {
    final String activeBackend = customBackendUrl ?? cloudBackendUrl ?? backendBaseUrl;

    // 1. Try Backend verification endpoint (/api/wallet/verify-order)
    if (activeBackend.isNotEmpty) {
      try {
        final String url = '${activeBackend.replaceAll(RegExp(r'/+$'), '')}/api/wallet/verify-order';
        debugPrint('[Cashfree Wallet] Verifying order on backend: $url');
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'orderId': orderId,
                'userId': userId,
              }),
            )
            .timeout(const Duration(seconds: 6));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          debugPrint('[Cashfree Wallet] Verified on backend! New balance: ${data['newBalance']}');
          return {
            'success': true,
            'amountAdded': (data['amountAdded'] as num?)?.toDouble() ?? 0.0,
            'newBalance': (data['newBalance'] as num?)?.toDouble(),
            'alreadyProcessed': data['alreadyProcessed'] == true,
            'message': data['message'] ?? 'Wallet credited successfully',
          };
        } else if (response.statusCode == 400 && data['orderStatus'] != null) {
          return {
            'success': false,
            'orderStatus': data['orderStatus'],
            'message': data['message'] ?? 'Payment was not completed.',
          };
        }
      } catch (e) {
        debugPrint('[Cashfree Wallet] Backend verify error: $e. Checking direct gateway status.');
      }
    }

    // 2. Direct Cashfree verification fallback
    try {
      final bool isLive = useProduction && liveAppId.isNotEmpty;
      final String activeAppId = isLive ? liveAppId : sandboxAppId;
      final String activeSecret = isLive ? liveSecretKey : sandboxSecretKey;
      final String targetUrl = isLive
          ? 'https://api.cashfree.com/pg/orders/$orderId'
          : 'https://sandbox.cashfree.com/pg/orders/$orderId';

      debugPrint('[Cashfree Wallet] Verifying directly with $targetUrl');
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: {
          'x-client-id': activeAppId,
          'x-client-secret': activeSecret,
          'x-api-version': '2023-08-01',
        },
      ).timeout(const Duration(seconds: 6));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['order_status'] == 'PAID') {
        final double amt = (data['order_amount'] as num?)?.toDouble() ?? 0.0;
        return {
          'success': true,
          'amountAdded': amt,
          'isDirectVerified': true,
          'message': 'Payment verified directly with Cashfree',
        };
      }
    } catch (e) {
      debugPrint('[Cashfree Wallet] Direct verification error: $e');
    }

    return {'success': false, 'message': 'Could not verify payment status with server.'};
  }




  /// Start Cashfree Checkout (Supports Native UPI Intent, Direct UPI App Launch, or Web Checkout for Cards)
  Future<void> startCheckout({
    required String orderId,
    required String paymentSessionId,
    required CFEnvironment environment,
    String paymentMethod = 'web', // 'upi' or 'card' or 'web'
    String? upiAppPackage, // Specific package like 'com.phonepe.app', 'com.google.android.apps.nbu.paisa.user', 'net.one97.paytm'
    required PaymentSuccessCallback onSuccess,
    required PaymentFailureCallback onFailure,
  }) async {
    init();
    _activeOrderId = orderId;
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    try {
      final session = CFSessionBuilder()
          .setEnvironment(environment)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();
      _lastSession = session;

      if (paymentMethod == 'upi') {
        try {
          CFUPI upi;
          if (upiAppPackage != null && upiAppPackage.isNotEmpty) {
            debugPrint('[Cashfree] Launching specific UPI app intent: $upiAppPackage');
            upi = CFUPIBuilder()
                .setChannel(CFUPIChannel.INTENT)
                .setUPIID(upiAppPackage)
                .build();
          } else {
            debugPrint('[Cashfree] Launching native UPI Intent with UI (all installed apps)');
            upi = CFUPIBuilder()
                .setChannel(CFUPIChannel.INTENT_WITH_UI)
                .build();
          }

          final upiPayment = CFUPIPaymentBuilder()
              .setSession(session)
              .setUPI(upi)
              .build();

          await _cfPaymentGatewayService.doPayment(upiPayment);
          return;
        } catch (upiError) {
          debugPrint('[Cashfree UPI Native Error]: $upiError. Trying native UPI Intent chooser.');
          if (upiAppPackage != null) {
            try {
              final fallbackUpi = CFUPIBuilder()
                  .setChannel(CFUPIChannel.INTENT_WITH_UI)
                  .build();
              final upiFallbackPayment = CFUPIPaymentBuilder()
                  .setSession(session)
                  .setUPI(fallbackUpi)
                  .build();
              await _cfPaymentGatewayService.doPayment(upiFallbackPayment);
              return;
            } catch (fallbackError) {
              debugPrint('[Cashfree UPI Fallback Error]: $fallbackError');
            }
          }
        }
      }

      final theme = CFThemeBuilder()
          .setNavigationBarBackgroundColorColor('#2E7D32') // Sabzee primary green
          .setNavigationBarTextColor('#FFFFFF')
          .setButtonBackgroundColor('#2E7D32')
          .setButtonTextColor('#FFFFFF')
          .setPrimaryFont('Roboto')
          .setSecondaryFont('Roboto')
          .build();

      final payment = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .setTheme(theme)
          .build();

      await _cfPaymentGatewayService.doPayment(payment);
    } on CFException catch (e) {
      debugPrint('[Cashfree CFException]: ${e.message}');
      onFailure(e.message, orderId);
    } catch (e) {
      debugPrint('[Cashfree Checkout Error]: $e');
      onFailure(e.toString(), orderId);
    }
  }
}
