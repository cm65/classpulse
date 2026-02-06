/// Form validation utilities for the ClassPulse app

class Validators {
  /// Validates an email address
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates an Indian mobile phone number (10 digits)
  static String? indianPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 10) {
      return 'Please enter a 10-digit number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Please enter a valid Indian mobile number';
    }
    return null;
  }

  /// Validates required text field
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates minimum length
  static String? minLength(String? value, int min, {String fieldName = 'This field'}) {
    if (value == null || value.trim().length < min) {
      return '$fieldName must be at least $min characters';
    }
    return null;
  }

  /// Validates maximum length
  static String? maxLength(String? value, int max, {String fieldName = 'This field'}) {
    if (value != null && value.trim().length > max) {
      return '$fieldName must be at most $max characters';
    }
    return null;
  }

  /// Validates OTP (6 digits)
  static String? otp(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }
    if (value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Please enter a valid 6-digit OTP';
    }
    return null;
  }

  /// Validates a name (alphabets and spaces only)
  static String? name(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    // Allow letters, spaces, and common name characters
    if (!RegExp(r"^[a-zA-Z\s\.\-']+$").hasMatch(value.trim())) {
      return 'Please enter a valid name';
    }
    return null;
  }

  /// Validates batch name
  static String? batchName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Batch name is required';
    }
    if (value.trim().length < 2) {
      return 'Batch name must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Batch name must be at most 50 characters';
    }
    return null;
  }

  /// Validates institute name
  static String? instituteName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Institute name is required';
    }
    if (value.trim().length < 3) {
      return 'Institute name must be at least 3 characters';
    }
    if (value.trim().length > 100) {
      return 'Institute name must be at most 100 characters';
    }
    return null;
  }

  /// Combines multiple validators
  static String? combine(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  }
}
