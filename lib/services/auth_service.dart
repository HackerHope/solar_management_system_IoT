import "package:firebase_auth/firebase_auth.dart";
import "solar_data_service.dart";
import "system_manager.dart";

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async {
    SolarDataService.disposeAllShared();
    SystemManager.instance.disposeShared();
    await _auth.signOut();
  }
}
