import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

// Global variable for appId from main.dart (assuming it's accessible)
const String appId = String.fromEnvironment(
  'APP_ID',
  defaultValue: 'default-app-id',
);

// Chatbot Screen
class ChatbotScreen extends StatefulWidget {
  final String userId;
  const ChatbotScreen({super.key, required this.userId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  // _messages will now be populated from Firestore stream
  final List<Map<String, String>> _messages = [];
  bool _isSending = false; // To show loading indicator for sending messages
  bool _isClearingHistory =
      false; // To show loading indicator for clearing history
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance

  // The Gemini API key will be automatically provided by the Canvas environment.
  // DO NOT hardcode your API key here.
  final String _apiKey =
      'AIzaSyDNYW14Aez4BxfRrzx6cImegu28Bp2W8Ro'; // CORRECT: Leave this empty. Canvas will inject the key.
  final String _geminiModel = 'gemini-1.5-flash'; // Your specified model

  // Firestore collection path for user's chat history
  late final CollectionReference _chatCollection;

  @override
  void initState() {
    super.initState();
    // Initialize the chat collection path
    _chatCollection = _firestore.collection(
      '/artifacts/$appId/users/${widget.userId}/chat_history',
    );
  }

  // Function to save a message (user or model) to Firestore
  Future<void> _saveMessageToFirestore(String role, String text) async {
    try {
      await _chatCollection.add({
        'role': role,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(), // Use server timestamp
      });
    } catch (e) {
      print('Error saving message to Firestore: $e');
      // Optionally show a snackbar for Firestore save errors
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to save message: ${e.toString()}')),
      // );
    }
  }

  // Function to send message to Gemini API and get response
  Future<void> _sendMessage() async {
    final String userMessage = _messageController.text.trim();
    if (userMessage.isEmpty) return; // Don't send empty messages

    // Add user message to local list and save to Firestore
    setState(() {
      _messages.add({'role': 'user', 'text': userMessage});
      _messageController.clear();
      _isSending = true;
    });
    await _saveMessageToFirestore('user', userMessage);

    // --- IMPORTANT FIX: Limit the chat history sent to the API ---
    // Start with the system instruction
    List<Map<String, dynamic>> chatHistoryForApi = [
      {
        'role': 'user',
        'parts': [
          {
            'text':
                'You are an AI mental health assistant. Your purpose is to provide supportive, informative, and helpful responses related to mental well-being, coping strategies, mindfulness, and general mental health advice. Do not provide medical diagnoses or replace professional therapy. If a user asks for something outside of mental health, gently redirect them or state that you are focused on mental health topics. Always prioritize safety and well-being. Do not engage in harmful, unethical, or non-mental-health-related conversations.',
          },
        ],
      },
      {
        'role': 'model',
        'parts': [
          {
            'text':
                'Understood. I am ready to assist with mental health-related queries.',
          },
        ],
      },
    ];

    // Get the *actual* chat history from Firestore to ensure it's up-to-date and potentially limited
    // Fetch the last N messages from Firestore for context
    try {
      final QuerySnapshot chatSnapshot =
          await _chatCollection
              .orderBy('timestamp', descending: true) // Get most recent first
              .limit(
                10,
              ) // Limit to last 10 messages (adjust as needed for context/token limits)
              .get();

      // Add fetched messages to chatHistoryForApi in chronological order
      // We reverse because we fetched in descending order to get the latest easily
      final List<Map<String, dynamic>> fetchedMessages =
          chatSnapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'role': data['role'],
                  'parts': [
                    {'text': data['text']},
                  ],
                };
              })
              .toList()
              .reversed
              .toList(); // Reverse to get chronological order

      chatHistoryForApi.addAll(fetchedMessages);
    } catch (e) {
      print('Error fetching chat history for API: $e');
      // Continue without full history if fetching fails, but log the error.
      // The AI might lose some context but the app won't crash.
    }
    // --- END IMPORTANT FIX ---

    // Construct the API URL
    final String apiUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_apiKey';

    // Prepare the payload for the API request
    final Map<String, dynamic> payload = {'contents': chatHistoryForApi};

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        String aiResponse = '';

        // Parse the AI's response
        if (result['candidates'] != null &&
            result['candidates'].isNotEmpty &&
            result['candidates'][0]['content'] != null &&
            result['candidates'][0]['content']['parts'] != null &&
            result['candidates'][0]['content']['parts'].isNotEmpty) {
          aiResponse = result['candidates'][0]['content']['parts'][0]['text'];
        } else {
          aiResponse = 'Sorry, I could not get a response. Please try again.';
          print('Gemini API response structure unexpected: $result');
        }

        // Add AI response to local list and save to Firestore
        setState(() {
          _messages.add({'role': 'model', 'text': aiResponse});
        });
        await _saveMessageToFirestore('model', aiResponse);
      } else {
        String errorMsg = 'Error: ${response.statusCode} - ${response.body}';
        setState(() {
          _messages.add({'role': 'model', 'text': errorMsg});
        });
        await _saveMessageToFirestore('model', errorMsg);
        print('Gemini API Error: $errorMsg');
      }
    } catch (e) {
      String errorMsg = 'Network error: $e';
      setState(() {
        _messages.add({'role': 'model', 'text': errorMsg});
      });
      await _saveMessageToFirestore('model', errorMsg);
      print('Network error calling Gemini API: $e');
    } finally {
      setState(() {
        _isSending = false; // Stop loading indicator
      });
    }
  }

  // Function to clear all chat history for the current user
  Future<void> _clearChatHistory() async {
    // Show confirmation dialog before clearing
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Chat History?'),
          content: const Text(
            'Are you sure you want to delete all your chat messages? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // User cancels
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // User confirms
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isClearingHistory = true;
      });

      try {
        final QuerySnapshot snapshot = await _chatCollection.get();

        // Delete each document in the collection
        for (DocumentSnapshot doc in snapshot.docs) {
          await doc.reference.delete();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat history cleared successfully!')),
        );
        // Clear local messages list immediately after successful deletion
        setState(() {
          _messages.clear();
          // Re-add initial welcome message after clearing
          _messages.add({
            'role': 'model',
            'text':
                'I am your AI mental health assistant. How can I help you today?',
          });
        });
      } catch (e) {
        print('Error clearing chat history: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear chat history: ${e.toString()}'),
          ),
        );
      } finally {
        setState(() {
          _isClearingHistory = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with "Clear Chat" button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Chatbot',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColorDark,
                ),
              ),
              _isClearingHistory
                  ? const CircularProgressIndicator()
                  : TextButton.icon(
                    onPressed: _clearChatHistory,
                    icon: Icon(Icons.delete_forever, color: Colors.red[700]),
                    label: Text(
                      'Clear Chat',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _chatCollection
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading chat: ${snapshot.error}'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Clear local messages and rebuild from Firestore data
              _messages.clear();
              snapshot.data!.docs.forEach((doc) {
                final data = doc.data() as Map<String, dynamic>;
                _messages.add({
                  'role':
                      data['role'] ??
                      'model', // Default to model if role is missing
                  'text': data['text'] ?? 'Message content missing',
                });
              });

              // Add initial welcome message if chat is empty after loading from Firestore
              // This ensures the welcome message is always present when chat is empty
              if (_messages.isEmpty) {
                _messages.add({
                  'role': 'model',
                  'text':
                      'I am your AI mental health assistant. How can I help you today?',
                });
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color:
                            isUser
                                ? Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.8)
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Text(
                        message['text']!,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_isSending) // Show loading indicator
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(), // Send on Enter key
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed:
                      _isSending
                          ? null
                          : _sendMessage, // Disable button while sending
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
