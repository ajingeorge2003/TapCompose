import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ui/auth_screen.dart';
import 'ui/home_screen.dart';
import 'ui/midi_arranger.dart';
import 'ui/live_record_screen.dart'; // Import the new screen

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapCompose',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFBB86FC),
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/arranger': (context) => const AdvancedMidiArrangerScreen(),
        // Add the new route here
        '/live-record': (context) => const LiveRecordScreen(),
      },
    );
  }
}
