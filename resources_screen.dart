import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs

// Global variable for appId from main.dart (assuming it's accessible)
const String appId = String.fromEnvironment('APP_ID', defaultValue: 'default-app-id');

// Resources Screen
class ResourcesScreen extends StatelessWidget {
  final String userId; // userId is passed but not directly used in this screen's logic
  const ResourcesScreen({super.key, required this.userId});

  // Helper function to map string icon names to IconData
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

  // Function to launch a URL (for articles, videos, audio)
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

  // Helper widget to build resource categories
  Widget _buildResourceCategory(
      BuildContext context, String categoryTitle, List<Map<String, dynamic>> items, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(
          categoryTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColorDark,
          ),
        ),
        children: items.map((item) {
          final String title = item['title'] ?? 'No Title';
          final String description = item['description'] ?? '';
          final String url = item['url'] ?? '';
          final String type = item['type'] ?? 'article'; // Default to article

          IconData trailingIcon;
          if (type == 'video') {
            trailingIcon = Icons.play_circle_fill;
          } else if (type == 'audio') {
            trailingIcon = Icons.audiotrack;
          } else {
            trailingIcon = Icons.launch; // For articles/web pages
          }

          return ListTile(
            title: Text(title),
            subtitle: description.isNotEmpty ? Text(description) : null,
            trailing: Icon(trailingIcon, color: Theme.of(context).hintColor),
            onTap: () {
              if (url.isNotEmpty) {
                _launchUrl(context, url);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resource URL not available.')),
                );
              }
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define the Firestore collection path for public resources
    final String collectionPath = '/artifacts/$appId/public/data/resources';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mental Wellness Resources',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColorDark,
            ),
          ),
          const SizedBox(height: 20),
          // StreamBuilder to fetch resources from Firestore in real-time
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(collectionPath).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading resources: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No resources available yet.'));
              }

              // Group resources by category
              final Map<String, List<Map<String, dynamic>>> categorizedResources = {};
              snapshot.data!.docs.forEach((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final category = data['category'] ?? 'Uncategorized';
                if (!categorizedResources.containsKey(category)) {
                  categorizedResources[category] = [];
                }
                categorizedResources[category]!.add(data);
              });

              // Build ExpansionTiles for each category
              return Column(
                children: categorizedResources.entries.map((entry) {
                  final String categoryTitle = entry.key;
                  final List<Map<String, dynamic>> items = entry.value;
                  // Attempt to get a category icon from the first item, or use a default
                  IconData categoryIcon = Icons.library_books; // Default icon
                  if (items.isNotEmpty && items[0]['iconName'] != null) {
                    categoryIcon = _getIconData(items[0]['iconName']!);
                  }

                  return _buildResourceCategory(
                    context,
                    categoryTitle,
                    items,
                    categoryIcon,
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
