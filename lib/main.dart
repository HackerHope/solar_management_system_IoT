import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "firebase_options.dart";
import "screens/home_shell.dart";
import "screens/login_screen.dart";
import "services/push_service.dart";
import "services/auth_service.dart";
import "services/system_manager.dart";
import "theme.dart";

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SystemManager.instance.load();
  await PushService.init();
  PushService.listenForeground(messengerKey);
  runApp(const SolarIotApp());
}

class SolarIotApp extends StatelessWidget {
  const SolarIotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "SolarIoT",
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

// Swaps between Login and the main app shell based on Firebase Auth state -
// mirrors ProtectedRoute + AuthContext on the web app.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          // Rebuilt (with fresh stream subscriptions) whenever the active
          // system changes - AnimatedBuilder + ValueKey handles that cleanly.
          return AnimatedBuilder(
            animation: SystemManager.instance,
            builder: (context, _) {
              return HomeShell(key: ValueKey(SystemManager.instance.currentSystemId));
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}
