import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:sqflite/sqflite.dart';

void initDesktopDb() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
