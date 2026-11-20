// ignore_for_file: depend_on_referenced_packages
import 'dart:ffi';
import 'package:sqlite3/open.dart';

void setupTestSqlite() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );
}
