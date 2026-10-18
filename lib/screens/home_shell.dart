import "package:flutter/material.dart";
import "../services/auth_service.dart";
import "../services/push_service.dart";
import "../services/system_manager.dart";
import "about_screen.dart";
import "alerts_screen.dart";
import "analytics_screen.dart";
import "dashboard_screen.dart";
import "devices_screen.dart";
import "settings_screen.dart";
import "solar_system_screen.dart";
import "systems_screen.dart";

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // HomeShell is rebuilt (new key) whenever the active system changes, so
    // this keeps the push-notification topic in step with the chosen system.
    PushService.subscribeTo(SystemManager.instance.currentSystemId);
  }

  // Bottom nav holds the 4 most-used screens; the rest live behind "More"
  // (a simple menu) to keep the nav bar from getting cramped on phones.
  final _primaryScreens = const [
    DashboardScreen(),
    DevicesScreen(),
    AnalyticsScreen(),
    AlertsScreen(),
  ];

  void _openMore() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101B31),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text("Solar System"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text("Solar System")),
                        body: const SolarSystemScreen(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text("Systems"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text("Systems")),
                        body: const SystemsScreen(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text("Settings"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text("Settings")),
                        body: const SettingsScreen(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("About Us"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text("About Us")),
                        body: const AboutScreen(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Sign out"),
                onTap: () async {
                  Navigator.pop(context);
                  await _authService.logout();
                  // Navigation back to Login happens via authStateChanges() in main.dart
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _primaryScreens[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          if (i == 4) {
            _openMore();
            return;
          }
          setState(() => _index = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.memory), label: "Devices"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Analytics"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: "Alerts"),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: "More"),
        ],
      ),
    );
  }
}