import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:start/screens/main_app_screen.dart'; // Import MainAppScreen

// Authentication Screen
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Helper function to navigate to MainAppScreen
  void _navigateToMainAppScreen(User? user) {
    if (user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainAppScreen(userId: user.uid),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
  }

  // Function to handle user registration
  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous error messages
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    // Basic validation for empty fields
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a valid email and password!';
        _isLoading = false;
      });
      return;
    }

    // Basic email format validation (checking for '@' and '.')
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMessage =
            'Enter a correct email and password!'; // More general message as requested
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      if (kDebugMode) {
        print('Registration successful!');
      }
      _navigateToMainAppScreen(userCredential.user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        // Provide more user-friendly messages for common FirebaseAuth errors
        if (e.code == 'weak-password') {
          _errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'An account already exists for that email.';
        } else if (e.code == 'invalid-email') {
          _errorMessage =
              'The email address is not valid.'; // Specific for invalid format
        } else {
          _errorMessage =
              'Registration failed: ${e.message}'; // Fallback for other errors
        }
      });
      if (kDebugMode) {
        print('Registration error: ${e.code}: ${e.message}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
      print('Unexpected registration error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to handle user login
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous error messages
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    // Basic validation for empty fields
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a valid email and password!';
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      print('Login successful!');
      _navigateToMainAppScreen(userCredential.user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        // Provide more user-friendly messages for common FirebaseAuth errors
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          _errorMessage = 'Incorrect email or password.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'The email address is not valid.';
        } else {
          _errorMessage =
              'Login failed: ${e.message}'; // Fallback for other errors
        }
      });
      print('Login error: ${e.code}: ${e.message}');
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
      print('Unexpected login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to MindCare')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.self_improvement,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                'Your AI-Powered Mental Wellness Companion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColorDark,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(
                    Icons.email,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(
                    Icons.lock,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                obscureText: true,
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _login,
                      child: const Text('Login'),
                    ),
                  ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _register,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sign Up'),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Forgot Password functionality coming soon!',
                      ),
                    ),
                  );
                },
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
