import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/theme.dart';
import '../../utils/design_tokens.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _errorMessage;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool gotResponse = false;

    try {
      final authService = ref.read(authServiceProvider);

      // Add a timeout - if no response in 30 seconds, show error
      Future.delayed(const Duration(seconds: 30), () {
        if (!gotResponse && mounted && _isLoading) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Request timed out. Please check your internet connection and try again.';
          });
        }
      });

      await authService.sendOtp(
        phoneNumber: _phoneController.text.trim(),
        onCodeSent: (verificationId, resendToken) {
          gotResponse = true;
          if (mounted) {
            setState(() {
              _isLoading = false;
              _otpSent = true;
              _startResendCountdown();
            });
            _showSnackBar('OTP sent to ${_phoneController.text}');
          }
        },
        onError: (e) {
          gotResponse = true;
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = _getFirebaseErrorMessage(e);
            });
          }
        },
        onAutoVerified: (credential) async {
          gotResponse = true;
          // Auto-verification on Android
          await _signInWithCredential(credential);
        },
      );
    } catch (e) {
      gotResponse = true;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorHelpers.getUserFriendlyMessage(e);
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyOtp(_otpController.text.trim());
      // Navigation handled by AuthWrapper
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _getFirebaseErrorMessage(e);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorHelpers.getUserFriendlyMessage(e);
      });
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithCredential(credential);
      // Navigation handled by AuthWrapper
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _getFirebaseErrorMessage(e);
      });
    }
  }

  void _startResendCountdown() {
    _resendCountdown = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _resendCountdown--;
      });
      return _resendCountdown > 0;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Please enter a valid 10-digit number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),

                // Logo and title
                _buildHeader(),

                const SizedBox(height: 48),

                // Phone input or OTP input
                if (!_otpSent) ...[
                  _buildPhoneInput(),
                ] else ...[
                  _buildOtpInput(),
                ],

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorMessage(),
                ],

                const SizedBox(height: 24),

                // Action button
                _buildActionButton(),

                // Resend OTP
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  _buildResendButton(),
                ],

                // Change phone number
                if (_otpSent) ...[
                  const SizedBox(height: 8),
                  _buildChangePhoneButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.monitor_heart_outlined,
            size: 48,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'ClassPulse',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _otpSent
              ? 'Enter the OTP sent to\n${_phoneController.text}'
              : 'Enter your phone number to continue',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            hintText: 'Enter 10-digit mobile number',
            prefixText: '+91  ',
            counterText: '',
            prefixIcon: Icon(Icons.phone_android),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            if (value.length != 10) {
              return 'Please enter a valid 10-digit number';
            }
            if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
              return 'Please enter a valid Indian mobile number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter OTP',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 16,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'OTP Code',
            hintText: '------',
            counterText: '',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          onChanged: (value) {
            if (value.length == 6) {
              _verifyOtp();
            }
          },
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return LoadingButton(
      isLoading: _isLoading,
      onPressed: _otpSent ? _verifyOtp : _sendOtp,
      child: Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
    );
  }

  Widget _buildResendButton() {
    return TextButton(
      onPressed: _resendCountdown > 0 ? null : _sendOtp,
      child: Text(
        _resendCountdown > 0
            ? 'Resend OTP in $_resendCountdown seconds'
            : 'Resend OTP',
      ),
    );
  }

  Widget _buildChangePhoneButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          _otpSent = false;
          _otpController.clear();
          _errorMessage = null;
        });
      },
      child: const Text('Change phone number'),
    );
  }
}
