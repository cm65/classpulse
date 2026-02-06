import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../utils/helpers.dart';

/// Provider for the authentication service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

/// Provider for current user stream
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Provider for current teacher data
final currentTeacherProvider = StreamProvider<Teacher?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(authServiceProvider).getTeacherStream(user.uid);
});

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String? _verificationId;
  int? _resendToken;

  AuthService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Send OTP to phone number
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      // Format phone number with country code if not present
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: timeout,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
          onAutoVerified(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      onError(e);
    } catch (e) {
      // Wrap any other exception as FirebaseAuthException
      onError(FirebaseAuthException(
        code: 'unknown',
        message: e.toString(),
      ));
    }
  }

  /// Verify OTP and sign in
  Future<UserCredential> verifyOtp(String otp) async {
    if (_verificationId == null) {
      throw Exception('Please request OTP first');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    return signInWithCredential(credential);
  }

  /// Sign in with phone credential
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    final result = await _auth.signInWithCredential(credential);

    // Update last login time if teacher exists
    if (result.user != null) {
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(result.user!.uid)
          .get();

      if (teacherDoc.exists) {
        await teacherDoc.reference.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return result;
  }

  /// Check if user is new (no teacher record)
  Future<bool> isNewUser(String uid) async {
    final doc = await _firestore.collection('teachers').doc(uid).get();
    return !doc.exists;
  }

  /// Get teacher data stream
  Stream<Teacher?> getTeacherStream(String uid) {
    return _firestore
        .collection('teachers')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? Teacher.fromFirestore(doc) : null);
  }

  /// Get teacher by phone number
  Future<Teacher?> getTeacherByPhone(String phone) async {
    final formattedPhone = _formatPhoneNumber(phone);
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Try both formats
    final query = await _firestore
        .collection('teachers')
        .where('phone', whereIn: [phone, formattedPhone, cleanPhone])
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return Teacher.fromFirestore(query.docs.first);
  }

  /// Create teacher record (during registration)
  Future<void> createTeacher(Teacher teacher) async {
    await _firestore.collection('teachers').doc(teacher.id).set(
          teacher.toFirestore(),
        );
  }

  /// Check for pending invitation
  Future<TeacherInvitation?> getPendingInvitation(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    final query = await _firestore
        .collection('teacherInvitations')
        .where('phone', isEqualTo: cleanPhone)
        .where('isAccepted', isEqualTo: false)
        .orderBy('invitedAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final invitation = TeacherInvitation.fromFirestore(query.docs.first);
    return invitation.isValid ? invitation : null;
  }

  /// Accept invitation and create teacher record
  Future<void> acceptInvitation({
    required String uid,
    required String name,
    required TeacherInvitation invitation,
  }) async {
    final batch = _firestore.batch();

    // Create teacher record
    final teacherRef = _firestore.collection('teachers').doc(uid);
    batch.set(teacherRef, Teacher(
      id: uid,
      instituteId: invitation.instituteId,
      name: name,
      phone: invitation.phone,
      role: invitation.role,
      createdAt: DateTime.now(),
    ).toFirestore());

    // Mark invitation as accepted
    final invitationRef = _firestore
        .collection('teacherInvitations')
        .doc(invitation.id);
    batch.update(invitationRef, {'isAccepted': true});

    await batch.commit();
  }

  /// Sign out
  Future<void> signOut() async {
    _verificationId = null;
    _resendToken = null;
    await _auth.signOut();
  }

  /// Format phone number with +91 prefix (delegates to PhoneHelpers)
  String _formatPhoneNumber(String phone) {
    return PhoneHelpers.formatWithCountryCode(phone);
  }
}
