import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'intro_page.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize(); // Initialize notification service
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Warranty Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _loading = true;
  bool _firstTime = true;

  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('intro_seen') ?? false;

    // Check if user is already logged in
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      // If user is logged in, skip intro regardless of intro_seen flag
      if (user != null) {
        _firstTime = false;
      } else {
        _firstTime = !seen;
      }
      _loading = false;
    });
    print('DEBUG startup: intro_seen=${seen}, user=${user?.email}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_firstTime) {
      return const IntroPage(); // Make sure IntroPage sets 'intro_seen' = true
    }

    // Not first-time -> check Firebase Auth state
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in -> go to HomePage
          return const HomePage();
        } else {
          // No user -> go to LoginPage
          return const LoginPage();
        }
      },
    );
  }
}
