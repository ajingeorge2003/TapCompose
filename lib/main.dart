import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ui/auth_screen.dart';
import 'ui/home_screen.dart';
import 'ui/midi_arranger.dart';

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
      // Name changed here
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
      },
    );
  }
}
