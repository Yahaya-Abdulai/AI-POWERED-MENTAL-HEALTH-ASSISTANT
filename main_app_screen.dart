import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import the individual content screens
import 'package:start/screens/home_screen.dart'; // Adjust 'start' to your project name
import 'package:start/screens/chatbot_screen.dart'; // Adjust 'start' to your project name
import 'package:start/screens/mood_tracker_screen.dart'; // Adjust 'start' to your project name
import 'package:start/screens/resources_screen.dart'; // Adjust 'start' to your project name
import 'package:start/screens/emergency_screen.dart'; // Adjust 'start' to your project name

// Main Application Screen with Bottom Navigation
class MainAppScreen extends StatefulWidget {
  final String userId;

  const MainAppScreen({super.key, required this.userId});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomeScreen(userId: widget.userId),
      ChatbotScreen(userId: widget.userId),
      MoodTrackerScreen(userId: widget.userId),
      ResourcesScreen(userId: widget.userId),
      EmergencyScreen(userId: widget.userId),
    ];
    print('User ID in MainAppScreen: ${widget.userId}');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      print('User logged out successfully.');
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindCare AI Assistant'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                'ID: ${widget.userId.substring(0, 6)}...',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
          // IconButton(
          //   icon: const Icon(Icons.logout),
          //   onPressed: _logout,
          //   tooltip: 'Logout',
          // ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mood),
            label: 'Mood',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Resources',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_in_talk),
            label: 'Emergency',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
