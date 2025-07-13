import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.grey[100],
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
      bodySmall: TextStyle(color: Colors.grey, fontSize: 12),
      headlineMedium: TextStyle(
        color: Colors.white,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      bodyMedium: TextStyle(
        color: Colors.white70,
        fontSize: 15,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.5,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Colors.white,
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      scrimColor: Colors.black.withOpacity(0.3),
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.grey[100],
      selectedTileColor: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textColor: Colors.black87,
      iconColor: Colors.blue,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.grey[900],
    cardColor: Colors.grey[850],
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white70, fontSize: 16),
      bodySmall: TextStyle(color: Colors.grey, fontSize: 12),
      headlineMedium: TextStyle(
        color: Colors.white,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      bodyMedium: TextStyle(
        color: Colors.white70,
        fontSize: 15,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.5,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blueGrey,
      foregroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Colors.grey[900],
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      scrimColor: Colors.black.withOpacity(0.5),
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.grey[850],
      selectedTileColor: Colors.blueGrey[700],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textColor: Colors.white70,
      iconColor: Colors.blue,
    ),
  );
}

