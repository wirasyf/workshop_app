import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'settings_service.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SettingsService _settings;

  FirebaseAuthService(this._settings);

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  User? get currentUser => _auth.currentUser;

  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final userModel = UserModel.fromFirestore(doc);
        if (!userModel.isActive) {
          await signOut();
          return null;
        }
        return userModel;
      }
    }
    return null;
  }

  Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    final doc = await _firestore.collection('users').doc(credential.user!.uid).get();
    if (!doc.exists) {
      throw Exception('User data not found in Firestore');
    }
    
    final userModel = UserModel.fromFirestore(doc);
    if (!userModel.isActive) {
      await _auth.signOut();
      throw Exception('Akun ini telah dinonaktifkan.');
    }

    final sessionId = const Uuid().v4();
    await _firestore.collection('users').doc(credential.user!.uid).update({
      'currentSessionId': sessionId,
    });
    
    final updatedModel = userModel.copyWith(currentSessionId: sessionId);
    await _settings.setUserId(userModel.id);
    await _settings.setUserName(userModel.name);
    await _settings.setUserRole(userModel.role);
    await _settings.setSessionId(sessionId);
    
    return updatedModel;
  }

  Future<UserModel> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    final sessionId = const Uuid().v4();
    
    final userModel = UserModel(
      id: credential.user!.uid,
      name: name,
      username: username,
      email: email,
      role: role,
      createdAt: DateTime.now(),
      currentSessionId: sessionId,
    );
    
    await _firestore.collection('users').doc(credential.user!.uid).set(userModel.toMap());
    
    await _settings.setUserId(userModel.id);
    await _settings.setUserName(userModel.name);
    await _settings.setUserRole(userModel.role);
    await _settings.setSessionId(sessionId);
    
    return userModel;
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _firestore.collection('users').doc(uid).update({
            'fcmTokens': FieldValue.arrayRemove([token]),
          });
        }
      } catch (e) {
        // Ignore errors if token is unavailable or network error
      }
    }
    await _auth.signOut();
    await _settings.clearUserSession();
  }
}
