import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static AudioService? _audioService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TapCompose"),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/auth');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF1E1E1E), Color(0xFF252525)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Welcome Back!",
                style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              // --- BUTTON FOR SEQUENCER ---
              ElevatedButton.icon(
                icon: const Icon(Icons.grid_on, color: Colors.black),
                label: const Text(
                  "Open Sequencer",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                  // Navigate to the MIDI arranger screen with no initial pattern.
                  Navigator.of(context).pushNamed('/arranger');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF03DAC6),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              // --- NEW BUTTON FOR LIVE RECORDING ---
              ElevatedButton.icon(
                icon: const Icon(Icons.mic, color: Colors.black),
                label: const Text(
                  "Live Beat to MIDI",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pushNamed('/live-record');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBB86FC),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              // --- TEST BEEP BUTTON ---
              ElevatedButton.icon(
                icon: const Icon(Icons.volume_up, color: Colors.black),
                label: const Text(
                  "Test Audio Beep",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () async {
                  print('DEBUG: Test beep button pressed');
                  
                  // Use singleton pattern to avoid creating multiple instances
                  if (_audioService == null) {
                    print('DEBUG: Creating new AudioService instance');
                    _audioService = AudioService();
                    await _audioService!.initialize();
                  }
                  
                  print('DEBUG: About to call testBeep()');
                  await _audioService!.testBeep();
                  print('DEBUG: testBeep() completed');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF44336),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
