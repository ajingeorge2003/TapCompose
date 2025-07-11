import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Navigate back to the auth screen, removing all previous routes.
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
              ElevatedButton.icon(
                icon: const Icon(Icons.music_note, color: Colors.black),
                label: const Text(
                  "Open Arranger",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                  // Navigate to the MIDI arranger screen.
                  Navigator.of(context).pushNamed('/arranger');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF03DAC6),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              // You can add more UI elements here, like a list of recent projects.
            ],
          ),
        ),
      ),
    );
  }
}
