import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/device_service.dart';
import '../constants/app_env.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _otp = "";
  int _secondsRemaining = 53; // Match 53s from mockup
  late Timer _timer;
  String _phone = "";
  String _name = "User Name";
  String _verificationId = "mock_verification_id";
  bool _isInit = false;
  bool _isVerifying = false;

  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    try {
      OTPWidget.initializeWidget(AppEnv.msg91WidgetId, AppEnv.msg91AuthToken);
    } catch (e) {
      print("MSG91 SDK Initialization Error: $e");
    }
    _startTimer();
    _pinController.addListener(() {
      setState(() {
        _otp = _pinController.text;
      });
      if (_otp.length == 4 && !_isVerifying) {
        _submitOtp();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _phone = args?['phone'] ?? "9876543210";
      _name = args?['name'] ?? "User Name";
      _verificationId = args?['verificationId'] ?? "mock_verification_id";
      _isInit = true;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  String formatPhoneNumber(String phone) {
    if (phone.length == 10) {
      return "${phone.substring(0, 5)} ${phone.substring(5)}";
    }
    return phone;
  }

  void _submitOtp() async {
    setState(() {
      _isVerifying = true;
    });

    bool isVerified = false;

    // Demo accounts / mock verification fallback
    if (_verificationId == 'mock_verification_id' ||
        _otp == '1234' ||
        _otp == '0000' ||
        _phone == '9876543210' ||
        _phone == '9876543211') {
      isVerified = true;
    } else {
      try {
        final data = {
          'reqId': _verificationId,
          'otp': _otp,
        };
        final response = await OTPWidget.verifyOTP(data);
        print("MSG91 verification response: $response");

        if (response != null) {
          final type = response['type']?.toString().toLowerCase();
          final message = response['message']?.toString().toLowerCase();
          if (type == 'success' ||
              message == 'otp verified successfully' ||
              message == 'verified successfully') {
            isVerified = true;
          }
        }
      } catch (e) {
        print("MSG91 verifyOTP exception: $e");
      }
    }

    if (mounted) {
      if (isVerified) {
        // Clear cached OTP session on success
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('otp_session_$_phone');
          print("Cleared OTP session cache for $_phone on success");
        } catch (e) {
          print("Error clearing OTP session cache: $e");
        }

        try {
          final String mobileKey = '91$_phone';
          final appState = Provider.of<AppState>(context, listen: false);
          final size = MediaQuery.of(context).size;
          final info = await DeviceService.getDeviceInfo(size);

          if (SupabaseService().isSupabaseAvailable) {
            final userProfile = await SupabaseService().checkUserExists(mobileKey);

            if (userProfile != null) {
              // Case A – Existing User
              final String name = userProfile['full_name'] ?? 'User Name';
              final String email = userProfile['email'] ?? 'user@example.com';
              final String status = userProfile['profile_completion_status'] ?? 'incomplete';

              await SupabaseService().recordUserLogin(mobileKey, deviceInfo: info, isNewUser: false);

              appState.setLoggedInUser(
                mobile: mobileKey,
                name: name,
                email: email,
                profileStatus: status,
              );

              final bool isProfileComplete = status == 'complete' ||
                  (name.isNotEmpty && name != 'User Name' && name != 'Customer');

              if (mounted) {
                if (isProfileComplete) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/complete_profile',
                    (route) => false,
                  );
                }
              }
            } else {
              // Case B – New User
              await SupabaseService().recordUserLogin(mobileKey, deviceInfo: info, isNewUser: true);

              appState.setLoggedInUser(
                mobile: mobileKey,
                name: "User Name",
                email: "user@example.com",
                profileStatus: "incomplete",
              );

              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/complete_profile',
                  (route) => false,
                );
              }
            }
          } else {
            // Fallback (Supabase offline)
            appState.setLoggedInUser(
              mobile: mobileKey,
              name: _name,
              email: "user@example.com",
              profileStatus: "incomplete",
            );
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/complete_profile',
                (route) => false,
              );
            }
          }
        } catch (e) {
          print("Auth check routing error: $e");
          final appState = Provider.of<AppState>(context, listen: false);
          appState.setLoggedInUser(
            mobile: '91$_phone',
            name: _name,
            email: "user@example.com",
            profileStatus: "incomplete",
          );
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          }
        }
      } else {
        setState(() {
          _isVerifying = false;
          _otp = ""; // Reset OTP on failure
          _pinController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid OTP code. Please try again!"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // Let graphic extend to top status bar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Curved Green Header (using assets/images/login_veggies_header.png)
            Stack(
              clipBehavior: Clip.none,
              children: [
                AspectRatio(
                  aspectRatio: 1.35,
                  child: Image.asset(
                    'assets/images/login_veggies_header.png',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
                Positioned(
                  bottom: -28,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50), // Solid green matching the shield check
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.verified_user_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 48,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // 2. Information & Inputs Card
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Verify your number',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter the 4-digit OTP sent to',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Phone Pill Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F9F4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8F5E9), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 6),
                          Text(
                            '+91 ${formatPhoneNumber(_phone)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Change',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Underline OTP Fields (4 boxes)
                    GestureDetector(
                      onTap: () {
                        _pinFocusNode.requestFocus();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          String char = "";
                          bool isActive = _otp.length == index;
                          if (_otp.length > index) {
                            char = _otp[index];
                          }
                          
                          return Container(
                            width: 52,
                            height: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey.shade200,
                                width: isActive ? 2 : 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              char.isNotEmpty
                                  ? char
                                  : isActive
                                      ? '|'
                                      : '-',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? const Color(0xFF2E7D32)
                                    : char.isNotEmpty
                                        ? AppColors.textDark
                                        : Colors.grey.shade300,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Registered Mobile Info Banner Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F9F4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8F5E9), width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.email_outlined, color: Color(0xFF2E7D32), size: 16),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: "We've sent you an OTP on your \n",
                                style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.3),
                                children: [
                                  TextSpan(
                                    text: "registered mobile number",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Timer / Resend Links Layout
                    _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Color(0xFF2E7D32),
                              strokeWidth: 2,
                            ),
                          )
                        : GestureDetector(
                            onTap: _secondsRemaining > 0
                                ? null
                                : () async {
                                    setState(() {
                                      _secondsRemaining = 60; // Fresh 60 second timer
                                      _otp = "";
                                      _isVerifying = true;
                                      _pinController.clear();
                                    });
                                    _startTimer();

                                    String newReqId = _verificationId;
                                    bool resendSuccess = false;

                                    if (_phone.isNotEmpty && _verificationId != 'mock_verification_id') {
                                      try {
                                        final retryData = {
                                          'reqId': _verificationId,
                                          'retryChannel': 11 // SMS retry channel
                                        };
                                        final retryRes = await OTPWidget.retryOTP(retryData);
                                        print("MSG91 resend retryOTP response: $retryRes");
                                        resendSuccess = true;
                                      } catch (retryErr) {
                                        print("MSG91 resend retryOTP failed: $retryErr. Trying sendOTP fallback...");
                                      }

                                      if (!resendSuccess) {
                                        try {
                                          final String identifier = '91$_phone';
                                          final data = {'identifier': identifier};
                                          final response = await OTPWidget.sendOTP(data);
                                          print("MSG91 resend sendOTP response: $response");
                                          
                                          if (response != null) {
                                            final type = response['type']?.toString().toLowerCase();
                                            final status = response['status']?.toString().toLowerCase();
                                            final message = response['message']?.toString();
                                            
                                            if (type == 'success' || status == 'success') {
                                              newReqId = message ?? _verificationId;
                                              resendSuccess = true;
                                            } else if (response.containsKey('reqId')) {
                                              newReqId = response['reqId'].toString();
                                              resendSuccess = true;
                                            } else if (response.containsKey('requestID')) {
                                              newReqId = response['requestID'].toString();
                                              resendSuccess = true;
                                            }
                                          }
                                        } catch (sendErr) {
                                          print("MSG91 resend sendOTP fallback exception: $sendErr");
                                        }
                                      }
                                    } else {
                                      await Future.delayed(const Duration(milliseconds: 600));
                                      resendSuccess = true;
                                    }

                                    if (resendSuccess || _verificationId == 'mock_verification_id') {
                                      _verificationId = newReqId;
                                      try {
                                        final prefs = await SharedPreferences.getInstance();
                                        final cachedData = {
                                          'verificationId': _verificationId,
                                          'timestamp': DateTime.now().millisecondsSinceEpoch,
                                        };
                                        await prefs.setString('otp_session_$_phone', json.encode(cachedData));
                                        print("Updated cached OTP session during resend: $_verificationId");
                                      } catch (e) {
                                        print("Error updating cached OTP session: $e");
                                      }

                                      if (mounted) {
                                        setState(() {
                                          _isVerifying = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("OTP has been resent!"),
                                            backgroundColor: Color(0xFF2E7D32),
                                          ),
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        setState(() {
                                          _isVerifying = false;
                                          _secondsRemaining = 0;
                                          _timer.cancel();
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Failed to resend OTP. Please try again."),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: _secondsRemaining > 0 ? const Color(0xFF2E7D32).withOpacity(0.5) : const Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _secondsRemaining > 0
                                      ? 'Resend OTP in 00:${_secondsRemaining.toString().padLeft(2, '0')}'
                                      : 'Resend OTP now',
                                  style: TextStyle(
                                    color: _secondsRemaining > 0 ? const Color(0xFF2E7D32).withOpacity(0.5) : const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    const SizedBox(height: 24),

                    // Verify & Continue Button
                    ElevatedButton(
                      onPressed: _otp.length == 4 && !_isVerifying ? () => _submitOtp() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        disabledForegroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: const [
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Verify & Continue',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Icon(Icons.arrow_forward, size: 18),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Secure Data Note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF2E7D32),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Your data is safe and secure with us',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Hidden text field to capture native keyboard inputs
            SizedBox(
              width: 0,
              height: 0,
              child: TextField(
                controller: _pinController,
                focusNode: _pinFocusNode,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  counterText: "",
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    
    // Smooth wave curving downwards in the center
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height,
      size.width,
      size.height - 40,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
