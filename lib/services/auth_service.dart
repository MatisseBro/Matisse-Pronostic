import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> register(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
}
