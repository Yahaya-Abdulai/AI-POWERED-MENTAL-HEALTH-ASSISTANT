import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart'; // For date formatting
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs

// Global variable for appId from main.dart (assuming it's accessible)
const String appId = String.fromEnvironment('APP_ID', defaultValue: 'default-app-id');

// Home Screen (Dashboard)
class HomeScreen extends StatefulWidget {
  final String userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedQuickMoodEmoji; // For the quick check-in section
  Map<String, dynamic>? _latestMoodEntry; // To display the last logged mood

  // List of available mood emojis for quick check-in
  final List<Map<String, String>> _moodOptions = [
    {'emoji': '😊', 'label': 'Happy'},
    {'emoji': '😐', 'label': 'Neutral'},
    {'emoji': '😔', 'label': 'Sad'},
    {'emoji': '😡', 'label': 'Angry'},
  ];

  // Mapping from mood label (from _latestMoodEntry) to recommendation tags
  // These tags should match values in the 'relatedMoods' array in Firestore documents.
  final Map<String, List<String>> _moodToRecommendationTags = {
    'Happy': ['happy', 'gratitude', 'wellbeing', 'mindfulness'],
    'Neutral': ['mindfulness', 'productivity', 'self_care'],
    'Sad': ['sadness', 'coping_strategies', 'emotional_support', 'self_compassion'],
    'Angry': ['anger_management', 'stress_relief', 'coping_strategies'],
    'Joyful': ['happy', 'gratitude', 'wellbeing', 'mindfulness'], // From MoodTrackerScreen
    'Anxious': ['anxiety_relief', 'grounding_techniques', 'stress_relief'], // From MoodTrackerScreen
    'Tired': ['sleep_hygiene', 'relaxation'], // From MoodTrackerScreen
    'Frustrated': ['stress_relief', 'coping_strategies'], // From MoodTrackerScreen
  };


  @override
  void initState() {
    super.initState();
    _fetchLatestMood(); // Fetch initial mood on screen load
  }

  // Function to fetch the latest mood entry from Firestore
  void _fetchLatestMood() {
    final String collectionPath = '/artifacts/$appId/users/${widget.userId}/mood_entries';
    _firestore.collection(collectionPath)
        .orderBy('timestamp', descending: true) // Requires Firestore index
        .limit(1)
        .snapshots() // Use snapshots for real-time updates
        .listen((snapshot) {
      if (mounted) { // Check if widget is still mounted before setState
        if (snapshot.docs.isNotEmpty) {
          setState(() {
            _latestMoodEntry = snapshot.docs.first.data() as Map<String, dynamic>;
          });
        } else {
          setState(() {
            _latestMoodEntry = null;
          });
        }
      }
    });
  }

  // Function to save a quick mood entry from the dashboard
  Future<void> _saveQuickMoodEntry() async {
    if (_selectedQuickMoodEmoji == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood emoji!')),
      );
      return;
    }

    try {
      final String collectionPath = '/artifacts/$appId/users/${widget.userId}/mood_entries';
      await _firestore.collection(collectionPath).add({
        'mood': _selectedQuickMoodEmoji,
        'journal': 'Quick check-in from dashboard.', // Default journal for quick entry
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.userId,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mood logged successfully!')),
      );
      setState(() {
        _selectedQuickMoodEmoji = null; // Clear selection after saving
      });
    } catch (e) {
      print('Error saving quick mood: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log mood: ${e.toString()}')),
      );
    }
  }

  // Function to launch a URL (for recommended resources)
  Future<void> _launchUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open resource: $url')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching URL: ${e.toString()}')),
      );
      print('Error launching URL: $e');
    }
  }

  // Helper function to map string icon names to IconData for resources
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'self_improvement':
        return Icons.self_improvement;
      case 'psychology':
        return Icons.psychology;
      case 'article':
        return Icons.article;
      case 'video_library':
        return Icons.video_library;
      case 'audiotrack':
        return Icons.audiotrack;
      default:
        return Icons.info_outline; // Default icon
    }
  }

  // Helper widget to build mood emoji buttons for quick check-in
  Widget _buildMoodEmoji(BuildContext context, String emoji, String label) {
    bool isSelected = _selectedQuickMoodEmoji == emoji;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedQuickMoodEmoji = emoji;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: $label')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.3) : Theme.of(context).hintColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).hintColor.withOpacity(0.5),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 30),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine the mood label from the latest mood entry
    String? latestMoodLabel;
    if (_latestMoodEntry != null && _latestMoodEntry!['mood'] != null) {
      // Find the label corresponding to the emoji
      latestMoodLabel = _moodOptions.firstWhere(
        (option) => option['emoji'] == _latestMoodEntry!['mood'],
        orElse: () => {'label': 'Unknown'}, // Fallback if emoji not found
      )['label'];
    }

    // Get relevant tags based on the latest mood label
    List<String> relevantTags = [];
    if (latestMoodLabel != null) {
      relevantTags = _moodToRecommendationTags[latestMoodLabel] ?? [];
    }

    // Determine the Firestore query based on relevant tags
    Query<Map<String, dynamic>> recommendationsQuery;
    if (relevantTags.isNotEmpty) {
      // If there are relevant tags, filter by them
      recommendationsQuery = FirebaseFirestore.instance
          .collection('/artifacts/$appId/public/data/resources')
          .where('relatedMoods', arrayContainsAny: relevantTags)
          .limit(3); // Still limit to 3 for dashboard
    } else {
      // If no specific mood or tags, get general recommendations (first 3)
      recommendationsQuery = FirebaseFirestore.instance
          .collection('/artifacts/$appId/public/data/resources')
          .limit(3);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColorDark,
            ),
          ),
          const SizedBox(height: 20),

          // Display Latest Mood Entry
          Card(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Latest Mood:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _latestMoodEntry == null
                      ? Text(
                          'No mood logged yet. How are you feeling?',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        )
                      : Row(
                          children: [
                            Text(
                              _latestMoodEntry!['mood'] ?? '❓',
                              style: const TextStyle(fontSize: 40),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _latestMoodEntry!['journal'] ?? 'No journal entry.',
                                    style: const TextStyle(fontSize: 16),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _latestMoodEntry!['timestamp'] != null
                                        ? DateFormat('MMM d, yyyy - hh:mm a').format(
                                            (_latestMoodEntry!['timestamp'] as Timestamp).toDate())
                                        : 'Unknown Date',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        // This button can be used to navigate to the full Mood Tracker screen
                        // For simplicity, we'll use a snackbar here, but in a real app,
                        // you'd likely use a callback to change the selected tab in MainAppScreen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Navigate to Mood Tracker for full history!')),
                        );
                      },
                      icon: Icon(Icons.history, color: Theme.of(context).primaryColor),
                      label: Text('View Full History', style: TextStyle(color: Theme.of(context).primaryColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Quick Check-in Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Check-in',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'How are you feeling right now?',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _moodOptions.map((mood) {
                      return _buildMoodEmoji(
                        context,
                        mood['emoji']!,
                        mood['label']!,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _selectedQuickMoodEmoji == null ? null : _saveQuickMoodEntry,
                      child: const Text('Log Mood'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Recommended for You Section
          Text(
            'Recommended for You',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColorDark,
            ),
          ),
          const SizedBox(height: 16),
          // StreamBuilder to fetch recommended resources from Firestore based on mood
          StreamBuilder<QuerySnapshot>(
            stream: recommendationsQuery.snapshots(), // Use the dynamically created query
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading recommendations: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    relevantTags.isNotEmpty
                        ? 'No specific recommendations for your current mood. Here are some general resources.'
                        : 'No recommendations available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String title = data['title'] ?? 'No Title';
                  final String description = data['description'] ?? '';
                  final String url = data['url'] ?? '';
                  final String type = data['type'] ?? 'article';
                  final String iconName = data['iconName'] ?? 'info_outline';

                  IconData leadingIcon = _getIconData(iconName);
                  IconData trailingIcon;
                  if (type == 'video') {
                    trailingIcon = Icons.play_circle_fill;
                  } else if (type == 'audio') {
                    trailingIcon = Icons.audiotrack;
                  } else {
                    trailingIcon = Icons.launch;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Icon(leadingIcon, color: Theme.of(context).primaryColor, size: 30),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: description.isNotEmpty ? Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,) : null,
                      trailing: Icon(trailingIcon, color: Colors.grey[600]),
                      onTap: () {
                        if (url.isNotEmpty) {
                          _launchUrl(context, url);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Resource URL not available.')),
                          );
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
