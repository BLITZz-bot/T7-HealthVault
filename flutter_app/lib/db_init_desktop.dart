import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initializes the database factory for desktop platforms.
/// Keeps it as a no-op on mobile so that sqflite runs natively.
void initializeDatabase() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
