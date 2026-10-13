import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../constants/app_env.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Loaded securely from environment / AppEnv
  static const String msg91WidgetId = AppEnv.msg91WidgetId;
  static const String msg91AuthToken = AppEnv.msg91AuthToken;

  @override
  void initState() {
    super.initState();
    try {
      // Initialize the MSG91 SendOTP Widget configuration
      OTPWidget.initializeWidget(msg91WidgetId, msg91AuthToken);
    } catch (e) {
      print("MSG91 SDK Initialization Error: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final phone = _phoneController.text.trim();
    return phone.length == 10;
  }

  void _handleSendOtp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final name = "User Name";
      final phone = _phoneController.text.trim();

      String reqId = 'mock_verification_id';
      bool isSuccess = false;
      String errorMessage = '';

      // Call MSG91 to send OTP
      try {
        // Formatted number with country code e.g. 919876543210 (without +)
        final String identifier = '91$phone'; 
        final data = {'identifier': identifier};
        
        final response = await OTPWidget.sendOTP(data);
        print("MSG91 sendOTP response: $response");

        if (response != null) {
          final type = response['type']?.toString().toLowerCase();
          final status = response['status']?.toString().toLowerCase();
          final message = response['message']?.toString();
          
          if (type == 'success' || status == 'success') {
            reqId = message ?? '';
            isSuccess = true;
          } else if (response.containsKey('reqId')) {
            reqId = response['reqId'].toString();
            isSuccess = true;
          } else if (response.containsKey('requestID')) {
            reqId = response['requestID'].toString();
            isSuccess = true;
          } else if (type == 'error') {
            errorMessage = message ?? '';
          }
        }
      } catch (e) {
        print("MSG91 sendOTP Exception: $e.");
      }

      // Fallback: If sendOTP failed, check if we have a valid active cached session we can reuse & retry
      if (!isSuccess) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cachedStr = prefs.getString('otp_session_$phone');
          if (cachedStr != null) {
            final cached = json.decode(cachedStr);
            final int timestamp = cached['timestamp'] ?? 0;
            final int now = DateTime.now().millisecondsSinceEpoch;
            // 5 minutes (300,000 milliseconds) validity limit
            if (now - timestamp < 300000) {
              reqId = cached['verificationId'];
              isSuccess = true;
              print("Reusing active OTP session from cache: $reqId");
              
              // Trigger a retry using the reused reqId to ensure user gets a fresh SMS/OTP!
              try {
                final retryData = {
                  'reqId': reqId,
                  'retryChannel': 11 // SMS retry channel
                };
                final retryRes = await OTPWidget.retryOTP(retryData);
                print("MSG91 retryOTP during session reuse response: $retryRes");
              } catch (retryErr) {
                print("MSG91 retryOTP during session reuse failed: $retryErr");
              }
            }
          }
        } catch (e) {
          print("Error reading/handling cached OTP session: $e");
        }
      }

      // Fallback for demo/mock accounts (or if everything failed but we want to allow mock login)
      if (!isSuccess && (phone == '9876543210' || phone == '9876543211')) {
        reqId = 'mock_verification_id';
        isSuccess = true;
      }

      if (isSuccess) {
        // Cache the session if it's a real session
        if (reqId != 'mock_verification_id') {
          try {
            final prefs = await SharedPreferences.getInstance();
            final cachedData = {
              'verificationId': reqId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            };
            await prefs.setString('otp_session_$phone', json.encode(cachedData));
            print("Saved OTP session to cache for $phone: $reqId");
          } catch (e) {
            print("Error saving OTP session to cache: $e");
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          Navigator.pushNamed(
            context,
            '/otp',
            arguments: {
              'phone': phone,
              'name': name,
              'verificationId': reqId,
            },
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage.isNotEmpty ? errorMessage : "Failed to send OTP. Please try again later."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double W = MediaQuery.of(context).size.width;
    final double H = MediaQuery.of(context).size.height;

    double scaledWidth;
    double xxHeight = H;
    double leftOffset;
    double topOffset = 0;

    // Background image has an aspect ratio of 1000:1500 (2:3)
    if (H * (2 / 3) >= W) {
      // Height matches screen height
      // We scale the width to be the average of fill and cover, showing more side fruits with minor compression
      scaledWidth = (W + (H * 2 / 3)) / 2;
      leftOffset = (scaledWidth - W) / 2;
    } else {
      // Width matches screen width
      scaledWidth = W;
      xxHeight = W * 1.5;
      leftOffset = 0;
      topOffset = (xxHeight - H) / 2;
    }

    // Coordinates mapping from mockup image (size 1000x1500)
    // Input box: left=218px (21.8%), width=564px (56.4%), top=908px (60.5%), height=76px (5.1%)
    final double inputLeft = (0.218 * scaledWidth) - leftOffset;
    final double inputWidth = 0.564 * scaledWidth;
    final double inputTop = (0.605 * xxHeight) - topOffset;
    final double inputHeight = 0.051 * xxHeight;

    // Continue button: top=1002px (66.8%), height=76px (5.1%)
    final double buttonTop = (0.668 * xxHeight) - topOffset;
    final double buttonHeight = 0.051 * xxHeight;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Prevents resizing background when keyboard is shown
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            // Mockup Background Image (Full Screen - Sized to match intermediate scale)
            Positioned(
              left: -leftOffset,
              top: -topOffset,
              width: scaledWidth,
              height: xxHeight,
              child: Image.asset(
                'assets/images/Login Screen.png',
                fit: BoxFit.fill,
              ),
            ),

            // Working Mobile Number Input Overlay (Completely transparent inside printed box)
            Positioned(
              left: inputLeft,
              width: inputWidth,
              top: inputTop,
              height: inputHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent, // transparent background
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Stack(
                  children: [
                    // If user starts typing, overlay a white mask on the right to cover the printed hint text
                    if (_phoneController.text.isNotEmpty)
                      Positioned(
                        left: inputWidth * 0.40, // start after flag dropdown and vertical separator line
                        right: 2,
                        top: 2,
                        bottom: 2,
                        child: Container(
                          color: Colors.white, // hides the background hint text
                        ),
                      ),

                    // TextFormField Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          // Left transparent spacer matching flag + +91 drop area to align inputs
                          Container(
                            width: inputWidth * 0.35,
                            color: Colors.transparent,
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                                letterSpacing: 0.8,
                              ),
                              decoration: const InputDecoration(
                                hintText: '', // Empty: shows mockup's printed hint text underneath
                                counterText: '',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (value.length != 10) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Working Continue Button Overlay (Transparent tap area overlaying the printed button)
            Positioned(
              left: inputLeft,
              width: inputWidth,
              top: buttonTop,
              height: buttonHeight,
              child: InkWell(
                onTap: (_isFormValid && !_isLoading) ? _handleSendOtp : () {
                  if (!_isFormValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please enter a valid 10-digit mobile number"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  color: Colors.transparent,
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
