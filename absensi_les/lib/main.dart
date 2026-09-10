import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Absensi Les',
      theme: ThemeData(
        useMaterial3: true,
        // KOMBINASI WARNA MODERN INDIGO & AMBER
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5), 
          primary: const Color(0xFF3F51B5),
          secondary: Colors.amber[700], 
          surface: Colors.grey[50],
        ),
        // TEMA APP BAR
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3F51B5),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.0),
        ),
        // PERBAIKAN: Tema Tombol Tambah Melayang (Bulat Sempurna)
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF3F51B5),
          foregroundColor: Colors.white,
          shape: CircleBorder(), // Ini biar bulat bersih dan nggak kepotong
          elevation: 4,
        ),
      ),
      home: const MainScreen(),
    );
  }
}