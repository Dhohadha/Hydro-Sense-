import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gf1/view-model/auth/auth_state.dart';
import 'package:gf1/view/widgets/widgets.dart';
import 'package:pinput/pinput.dart';
import '../../view/utils/color_constants.dart';

class OtpVerificationPage extends StatefulWidget {
  final String verificationId;
  final String phone;

  const OtpVerificationPage({
    super.key,
    required this.verificationId,
    required this.phone,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final otpController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool isLoading = false;

  late String _verificationId; // Use state to hold the verificationId
  late Timer _timer;
  int _start = 30;
  bool _isResendButtonActive = false;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId; // Initialize with the passed ID
    startTimer();
  }

  void startTimer() {
    _isResendButtonActive = false;
    _start = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_start == 0) {
        setState(() {
          _isResendButtonActive = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void dispose() {
    otpController.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _verifyOtp() async {
    final otp = otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId, // Use the state variable
        smsCode: otp,
      );
      await _auth.signInWithCredential(credential);

      // *** FIX: Pop all screens until we get back to the AuthGate. ***
      // This prevents the PhoneNumberPage from showing up after login.
      // AuthGate will now reliably handle the navigation to the correct screen.
      if (mounted) {
        // Navigator.of(context).popUntil((route) => route.isFirst);

         Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
        
        //    Navigator.pushAndRemoveUntil(
        //   context,
        //   MaterialPageRoute(builder: (context) =>  MainNavigationPage()),
        //   (route) => false,
        // );

      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: ${e.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _resendOtp() async {
    setState(() {
      isLoading = true;
      _isResendButtonActive = false;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: widget.phone,
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Resend Failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A new OTP has been sent.')),
          );
          // Update the verificationId and restart the timer
          setState(() {
            _verificationId = verificationId;
          });
          startTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: textTheme.titleLarge,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.password_rounded,
                  size: 100,
                  color: AppColors.primaryColor,
                ),
                const SizedBox(height: 40),
                Text(
                  'OTP Verification',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: textTheme.titleMedium?.copyWith(color: Colors.black54),
                    children: [
                      const TextSpan(text: "Enter the 6-digit code sent to\n"),
                      TextSpan(
                        text: widget.phone,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Pinput(
                  length: 6,
                  controller: otpController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: AppColors.primaryColor),
                    ),
                  ),
                  submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      color: Colors.green.shade100,
                    ),
                  ),
                  onCompleted: (pin) => _verifyOtp(),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: _isResendButtonActive ? _resendOtp : null,
                      child: Text(
                        _isResendButtonActive
                            ? 'Resend OTP'
                            : 'Resend in $_start'
                                's',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isResendButtonActive
                              ? AppColors.primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Verify & Continue',
                    onPressed: _verifyOtp,
                    isLoading: isLoading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
