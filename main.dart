import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // Import for JSON decoding

// Import the new screen files
import 'package:start/screens/auth_screen.dart'; // Adjust 'start' to your project name if different
import 'package:start/screens/main_app_screen.dart'; // Adjust 'start' to your project name if different

// Global variables provided by the Canvas environment for Firebase configuration
const String appId = String.fromEnvironment('APP_ID', defaultValue: 'default-app-id');

// Helper function to safely parse the Firebase config JSON string.
Map<String, dynamic> _parseFirebaseConfig(String configString) {
  try {
    String cleanedString = configString.replaceAll('\\', '');
    if (cleanedString.isEmpty || cleanedString == 'null' || !cleanedString.startsWith('{')) {
      return {};
    }
    return json.decode(cleanedString) as Map<String, dynamic>;
  } catch (e) {
    print('Error parsing FIREBASE_CONFIG: $e');
    return {};
  }
}

final Map<String, dynamic> firebaseConfig = _parseFirebaseConfig(
  const String.fromEnvironment('FIREBASE_CONFIG', defaultValue: '{}'),
);
const String initialAuthToken = String.fromEnvironment('INITIAL_AUTH_TOKEN', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: firebaseConfig['apiKey'] ?? '',
        appId: firebaseConfig['appId'] ?? '',
        messagingSenderId: firebaseConfig['messagingSenderId'] ?? '',
        projectId: firebaseConfig['projectId'] ?? '',
        storageBucket: firebaseConfig['storageBucket'] ?? '',
      ),
    );

    final FirebaseAuth auth = FirebaseAuth.instance;
    // We keep this for Canvas environment's Firestore access requirement.
    // The AuthScreen will handle navigation if a user is already signed in.
    if (initialAuthToken.isNotEmpty) {
      await auth.signInWithCustomToken(initialAuthToken);
      print('Signed in with custom token via initialAuthToken.');
    } else {
      print('No custom token provided.');
    }

  } catch (e) {
    print('Error initializing Firebase or signing in: $e');
  }

  runApp(const App());
}

// The main application widget.
// This widget no longer directly manages the initial screen based on _user,
// but AuthScreen will handle the redirection if a user is already logged in.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // _user is no longer directly used for initial home screen decision here,
  // but the listener is still useful for general auth state changes.
  User? _user;

  @override
  void initState() {
    super.initState();
    // This listener is still active and will update _user,
    // but the initial navigation decision is now handled by AuthScreen.
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
        print('Auth state changed. User: ${_user?.uid ?? 'null'}');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindCare AI Assistant',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        primaryColor: const Color(0xFF4CAF50),
        hintColor: const Color(0xFF81C784),
        scaffoldBackgroundColor: const Color(0xFFE8F5E9),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF81C784), width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        cardTheme: CardTheme(
          margin: const EdgeInsets.all(8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
      ),
      // AuthScreen is now always the initial screen.
      // It will handle navigation if a user is already logged in.
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false, // <-- THIS LINE REMOVES THE DEBUG BANNER
    );
  }
}
