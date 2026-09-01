// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:sqflite/sqflite.dart';

// Stub — web path is handled via kIsWeb in database_helper.dart.
Future<Database> initDbNative() {
  throw UnsupportedError('Use the web DB path on web.');
}
