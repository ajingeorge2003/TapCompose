import 'package:flutter/material.dart';
import 'dart:math';

// This is a placeholder for the data you'll pass to the sequencer.
// In a real implementation, this would be generated from the live recording.
final List<List<bool>> sampleRecordedPattern = [
  [true, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false], // Kick
  [false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false], // Snare
  [true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false], // Hi-Hat
];


class LiveRecordScreen extends StatefulWidget {
  const LiveRecordScreen({super.key});

  @override
  State<LiveRecordScreen> createState() => _LiveRecordScreenState();
}

class _LiveRecordScreenState extends State<LiveRecordScreen> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  String _lastBeatDetected = "-";
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (!_isRecording) {
        _lastBeatDetected = "-";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Beat to MIDI"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF1E1E1E), Color(0xFF252525)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // --- VISUALIZER SECTION ---
              Column(
                children: [
                  Text(
                    _isRecording ? "Listening..." : "Ready to Record",
                    style: TextStyle(
                      color: _isRecording ? Colors.redAccent : Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 100,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(30, (index) {
                            final randomHeight = _isRecording ? (sin(_animationController.value * 2 * pi + index / 2) + 1.1) * 40 : 2.0;
                            return Container(
                              width: 5,
                              height: randomHeight,
                              decoration: BoxDecoration(
                                color: _isRecording ? const Color(0xFF03DAC6) : Colors.white24,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              // --- REAL-TIME FEEDBACK SECTION ---
              Column(
                children: [
                  const Text(
                    "LAST BEAT DETECTED",
                    style: TextStyle(color: Colors.white54, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _lastBeatDetected,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // --- CONTROLS SECTION ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red.shade900 : Colors.red,
                        border: Border.all(
                          color: Colors.white,
                          width: _isRecording ? 8 : 4,
                        ),
                        boxShadow: [
                          if (_isRecording)
                            BoxShadow(
                              color: Colors.red.withOpacity(0.7),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.grid_on, color: Colors.black),
                    label: const Text(
                      "Stop & Go to Sequencer",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      // Pass the recorded pattern to the arranger screen
                      Navigator.of(context).pushNamed(
                        '/arranger',
                        arguments: sampleRecordedPattern,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBB86FC),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
