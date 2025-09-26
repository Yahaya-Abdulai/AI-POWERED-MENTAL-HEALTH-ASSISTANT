import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs (calls/SMS)

// Emergency Screen
class EmergencyScreen extends StatelessWidget {
  final String
  userId; // userId is passed but not directly used in this screen's logic
  const EmergencyScreen({super.key, required this.userId});

  // Function to make a phone call
  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (!await launchUrl(launchUri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch call to $phoneNumber')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error making call: ${e.toString()}')),
      );
      print('Error launching phone call: $e');
    }
  }

  // Function to send an SMS
  Future<void> _sendSms(BuildContext context, String fullSmsString) async {
    // Example: "Text HOME to 0550822218"
    // We need to parse the number and body from this string.
    String phoneNumber = '';
    String messageBody = '';

    // Simple parsing for "Text MESSAGE to NUMBER" format
    final parts = fullSmsString.split(' to ');
    if (parts.length == 2) {
      messageBody = parts[0].replaceFirst('Text ', '').trim();
      phoneNumber = parts[1].trim();
    } else {
      // Fallback if format is unexpected, just try to use the whole string as path
      phoneNumber = fullSmsString;
    }

    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': messageBody},
    );

    try {
      if (!await launchUrl(launchUri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch SMS to $phoneNumber')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending SMS: ${e.toString()}')),
      );
      print('Error launching SMS: $e');
    }
  }

  // Helper widget to build emergency contact cards
  Widget _buildEmergencyContactCard(
    BuildContext context,
    String title,
    String contactInfo,
    IconData icon,
    Color color, {
    required bool isSms,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isSms) {
            _sendSms(context, contactInfo);
          } else {
            _makePhoneCall(context, contactInfo);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColorDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contactInfo,
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Icon(
                isSms ? Icons.sms : Icons.call,
                color: color,
              ), // Icon changes based on type
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.crisis_alert, size: 100, color: Colors.red[700]),
          const SizedBox(height: 32),
          Text(
            'If you are in crisis or need immediate help, please reach out to these resources.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).primaryColorDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          _buildEmergencyContactCard(
            context,
            'National Mental Health Helpline',
            '112', // Placeholder number
            Icons.phone,
            Colors.redAccent,
            isSms: false,
          ),
          const SizedBox(height: 16),
          _buildEmergencyContactCard(
            context,
            'Emergency Services',
            '911', // Placeholder number
            Icons.local_hospital,
            Colors.orangeAccent,
            isSms: false,
          ),
          const SizedBox(height: 16),
          _buildEmergencyContactCard(
            context,
            'Local Crisis Text Line',
            'Text HOME to 0550822218', // Placeholder text
            Icons.sms,
            Colors.blueAccent,
            isSms: true, // Mark this as an SMS contact
          ),
          const SizedBox(height: 40),
          Text(
            'Remember, you are not alone. Help is available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
