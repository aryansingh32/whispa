import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state_provider.dart';
import 'screens/main_screen.dart';

void main() {
  // Enable verbose logging in debug mode
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      print('[${DateTime.now().toString().split('.')[0]}] $message');
    }
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: MaterialApp(
        title: 'Whispa',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color.fromRGBO(32, 211, 102, 1),
          scaffoldBackgroundColor: const Color.fromRGBO(24, 24, 27, 1),
          colorScheme: const ColorScheme.dark(
            primary: Color.fromRGBO(32, 211, 102, 1),
            secondary: Color.fromRGBO(32, 211, 102, 1),
            surface: Color.fromRGBO(39, 39, 42, 1),
            background: Color.fromRGBO(24, 24, 27, 1),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromRGBO(39, 39, 42, 1),
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(color: Colors.white),
          ),
          cardTheme: CardThemeData(
            color: const Color.fromRGBO(39, 39, 42, 1),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color.fromRGBO(32, 211, 102, 1),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color.fromRGBO(24, 24, 27, 1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color.fromRGBO(32, 211, 102, 1),
                width: 2,
              ),
            ),
            hintStyle: const TextStyle(
              color: Color.fromRGBO(161, 161, 170, 1),
            ),
            labelStyle: const TextStyle(
              color: Color.fromRGBO(161, 161, 170, 1),
            ),
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}