import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart'; // For date formatting
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart for the graph

// Global variable for appId from main.dart (assuming it's accessible)
const String appId = String.fromEnvironment('APP_ID', defaultValue: 'default-app-id');

// Mood Tracker Screen
class MoodTrackerScreen extends StatefulWidget {
  final String userId;
  const MoodTrackerScreen({super.key, required this.userId});

  @override
  State<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends State<MoodTrackerScreen> {
  String? _selectedMoodEmoji;
  final TextEditingController _journalController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSavingMood = false; // To show loading indicator during save
  bool _isClearingHistory = false; // To show loading indicator during clearing

  // Variables for graph interactivity
  List<int> touchedSpots = []; // Stores indices of touched spots for highlighting

  // List of available mood emojis and their labels
  final List<Map<String, String>> _moodOptions = [
    {'emoji': '😄', 'label': 'Joyful'},
    {'emoji': '😊', 'label': 'Happy'},
    {'emoji': '😐', 'label': 'Neutral'},
    {'emoji': '😔', 'label': 'Sad'},
    {'emoji': '😟', 'label': 'Anxious'},
    {'emoji': '😠', 'label': 'Angry'},
    {'emoji': '😴', 'label': 'Tired'},
    {'emoji': '😤', 'label': 'Frustrated'},
  ];

  // Mapping from mood emoji to a numerical value for the graph
  final Map<String, double> _moodEmojiToValue = {
    '😄': 5.0, // Joyful
    '😊': 4.0, // Happy
    '😐': 3.0, // Neutral
    '😔': 2.0, // Sad
    '😟': 1.5, // Anxious (slightly above Angry for distinction)
    '😠': 1.0, // Angry
    '😴': 2.5, // Tired (can be neutral to slightly negative)
    '😤': 1.0, // Frustrated (same as angry for simplicity in graph)
  };

  // Function to save mood entry to Firestore
  Future<void> _saveMoodEntry() async {
    if (_selectedMoodEmoji == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood emoji!')),
      );
      return;
    }

    setState(() {
      _isSavingMood = true;
    });

    try {
      // Define the Firestore collection path for this user's mood entries (private data)
      final String collectionPath = '/artifacts/$appId/users/${widget.userId}/mood_entries';

      await _firestore.collection(collectionPath).add({
        'mood': _selectedMoodEmoji,
        'journal': _journalController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(), // Use server timestamp for consistency
        'userId': widget.userId, // Store userId for redundancy/querying if needed
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mood entry saved successfully!')),
      );
      _journalController.clear(); // Clear journal text field
      setState(() {
        _selectedMoodEmoji = null; // Clear selected mood
      });
    } catch (e) {
      print('Error saving mood: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save mood: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSavingMood = false;
      });
    }
  }

  // Function to clear all mood history for the current user
  Future<void> _clearMoodHistory() async {
    // Show confirmation dialog before clearing
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Mood History?'),
          content: const Text('Are you sure you want to delete all your mood entries? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // User cancels
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // User confirms
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Clear All', style: TextStyle(color: Colors.white)),
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
        final String collectionPath = '/artifacts/$appId/users/${widget.userId}/mood_entries';
        final QuerySnapshot snapshot = await _firestore.collection(collectionPath).get();

        // Delete each document in the collection
        for (DocumentSnapshot doc in snapshot.docs) {
          await doc.reference.delete();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mood history cleared successfully!')),
        );
      } catch (e) {
        print('Error clearing mood history: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear mood history: ${e.toString()}')),
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
    _journalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the Firestore collection path for this user's mood entries
    final String collectionPath = '/artifacts/$appId/users/${widget.userId}/mood_entries';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Mood Journey',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColorDark,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log Your Current Mood',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select the emoji that best describes how you feel right now:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Wrap( // Use Wrap for better responsiveness with many emojis
                    spacing: 8.0, // horizontal space
                    runSpacing: 8.0, // vertical space
                    children: _moodOptions.map((mood) {
                      return _buildMoodSelection(
                        context,
                        mood['emoji']!,
                        mood['label']!,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _journalController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Optional: Write about your day...',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.edit_note, color: Theme.of(context).hintColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _isSavingMood
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _saveMoodEntry,
                            child: const Text('Save Mood Entry'),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mood History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColorDark,
                ),
              ),
              _isClearingHistory
                  ? const CircularProgressIndicator()
                  : TextButton.icon(
                      onPressed: _clearMoodHistory, // Button to clear history
                      icon: Icon(Icons.delete_forever, color: Colors.red[700]),
                      label: Text(
                        'Clear All',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 16),
          // Mood History List (Real-time updates with StreamBuilder)
          // FIX: Wrap ListView.builder in a SizedBox to give it a fixed height
          SizedBox(
            height: 250, // You can adjust this height as needed
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection(collectionPath)
                  .orderBy('timestamp', descending: true)
                  .limit(10) // Show last 10 entries in the list
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading mood history: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No mood entries yet. Log your first mood!'));
                }

                return ListView.builder(
                  // shrinkWrap: true, // No longer strictly needed with fixed height, but harmless
                  // physics: const NeverScrollableScrollPhysics(), // No longer strictly needed with fixed height, but harmless
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final mood = data['mood'] ?? '❓';
                    final journal = data['journal'] ?? 'No journal entry.';
                    final timestamp = data['timestamp'] as Timestamp?; // Correctly cast to Timestamp?
                    final formattedDate = timestamp != null
                        ? DateFormat('MMM d, yyyy - hh:mm a').format(timestamp.toDate()) // This includes time
                        : 'Unknown Date'; // Fallback if timestamp is null

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  mood,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    formattedDate, // Display the formatted date and time
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              journal,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Mood Trends',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColorDark,
            ),
          ),
          const SizedBox(height: 16),
          // Mood Trends Graph (using StreamBuilder to get all data for the graph)
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection(collectionPath)
                .orderBy('timestamp', descending: false) // Order chronologically for graph
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading mood trends: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Card(
                  child: Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text(
                      'Log more moods to see your trends here!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                );
              }

              // Process data for the graph
              List<FlSpot> spots = [];
              double minX = 0;
              double maxX = 0;
              double minY = 0; // Mood values range from 1.0 to 5.0
              double maxY = 5.0; // Max mood value

              DateTime? firstTimestamp;
              if (snapshot.data!.docs.isNotEmpty) {
                firstTimestamp = (snapshot.data!.docs.first.data() as Map<String, dynamic>)['timestamp']?.toDate();
              }

              for (int i = 0; i < snapshot.data!.docs.length; i++) {
                final doc = snapshot.data!.docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final moodEmoji = data['mood'] ?? '😐'; // Default to Neutral if mood is missing
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

                final double moodValue = _moodEmojiToValue[moodEmoji] ?? 3.0; // Default to neutral value

                if (timestamp != null && firstTimestamp != null) {
                  // Calculate days since the first entry
                  final double xValue = timestamp.difference(firstTimestamp).inDays.toDouble();
                  spots.add(FlSpot(xValue, moodValue));
                } else {
                  // Fallback to index if timestamps are missing
                  spots.add(FlSpot(i.toDouble(), moodValue));
                }
              }

              if (spots.isEmpty) {
                 return Card(
                  child: Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text(
                      'Log more moods to see your trends here!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                );
              }

              // Determine min/max X values for the graph
              minX = spots.map((spot) => spot.x).reduce((a, b) => a < b ? a : b);
              maxX = spots.map((spot) => spot.x).reduce((a, b) => a > b ? a : b);

              // Ensure minX and maxX have at least a small range for single points
              if (minX == maxX) {
                minX = minX - 1;
                maxX = maxX + 1;
              }

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16), // Adjust padding for labels
                  child: SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        // Add LineTouchData for interactivity
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (LineBarSpot touchedSpot) => Colors.blueGrey.withOpacity(0.8),
                            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                              return touchedBarSpots.map((barSpot) {
                                final flSpot = barSpot; // Corrected line
                                
                                // Correctly retrieve mood label from _moodOptions
                                String moodLabel = 'Unknown';
                                final foundEntry = _moodOptions.firstWhere(
                                  (element) => _moodEmojiToValue[element['emoji']] == flSpot.y,
                                  orElse: () => {'label': 'Unknown', 'emoji': '❓'},
                                );
                                moodLabel = foundEntry['label']!;


                                String dateText = 'N/A';
                                if (firstTimestamp != null) {
                                  final DateTime date = firstTimestamp.add(Duration(days: flSpot.x.toInt()));
                                  dateText = DateFormat('MMM d, yyyy').format(date);
                                }

                                return LineTooltipItem(
                                  '$moodLabel: ${flSpot.y.toStringAsFixed(1)}\n',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: dateText,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                          touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                            setState(() {
                              if (event.isInterestedForInteractions &&
                                  touchResponse != null &&
                                  touchResponse.lineBarSpots != null) {
                                touchedSpots = touchResponse.lineBarSpots!.map((spot) => spot.spotIndex).toList();
                              } else {
                                touchedSpots = [];
                              }
                            });
                          },
                          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                            return spotIndexes.map((index) {
                              return TouchedSpotIndicatorData(
                                FlLine(color: Colors.white, strokeWidth: 2),
                                FlDotData(
                                  getDotPainter: (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 6,
                                      color: Colors.white,
                                      strokeWidth: 2,
                                      strokeColor: Theme.of(context).primaryColor,
                                    );
                                  },
                                ),
                              );
                            }).toList();
                          },
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 1,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return const FlLine(
                              color: Color(0xff37434d),
                              strokeWidth: 0.8,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return const FlLine(
                              color: Color(0xff37434d),
                              strokeWidth: 0.8,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: (maxX - minX) > 7 ? ((maxX - minX) / 5).ceilToDouble() : 1, // Dynamic interval
                              getTitlesWidget: (value, meta) {
                                // Display dates on the X-axis
                                final int days = value.toInt();
                                if (firstTimestamp != null) {
                                  final DateTime date = firstTimestamp.add(Duration(days: days));
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 8.0,
                                    child: Text(DateFormat('MMM d').format(date), style: const TextStyle(fontSize: 10)),
                                  );
                                }
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 8.0,
                                  child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 1, // Show labels for each mood level
                              getTitlesWidget: (value, meta) {
                                // Map numerical values back to mood labels for Y-axis
                                String text;
                                switch (value.toInt()) {
                                  case 1: text = 'Angry'; break;
                                  case 2: text = 'Sad'; break;
                                  case 3: text = 'Neutral'; break;
                                  case 4: text = 'Happy'; break;
                                  case 5: text = 'Joyful'; break;
                                  default: return const SizedBox.shrink();
                                }
                                return Text(text, style: const TextStyle(fontSize: 10));
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: const Color(0xff37434d), width: 1),
                        ),
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.5),
                                Theme.of(context).primaryColor,
                              ],
                            ),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: touchedSpots.contains(index) ? 8 : 4, // Bigger dot if touched
                                  color: touchedSpots.contains(index) ? Theme.of(context).primaryColor : Colors.white,
                                  strokeWidth: 1.5,
                                  strokeColor: Theme.of(context).primaryColor,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor.withOpacity(0.2),
                                  Theme.of(context).primaryColor.withOpacity(0),
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper widget for mood selection
  Widget _buildMoodSelection(BuildContext context, String emoji, String label) {
    bool isSelected = _selectedMoodEmoji == emoji;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMoodEmoji = emoji;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected mood: $label')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.3) : Theme.of(context).hintColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).hintColor.withOpacity(0.5),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
