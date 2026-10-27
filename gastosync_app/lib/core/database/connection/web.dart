import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart';
import 'package:sqlite3/wasm.dart';

QueryExecutor constructDb() {
  return LazyDatabase(() async {
    try {
      final byteData = await rootBundle.load('assets/sqlite3.wasm');
      final wasmBytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final sqlite3 = await WasmSqlite3.load(wasmBytes);

      try {
        final fileSystem = await IndexedDbFileSystem.open(
          dbName: 'gastosync_web',
        );
        sqlite3.registerVirtualFileSystem(fileSystem, makeDefault: true);
        return WasmDatabase(
          sqlite3: sqlite3,
          path: '/gastosync_app.db',
          fileSystem: fileSystem,
        );
      } catch (_) {
        sqlite3.registerVirtualFileSystem(
          InMemoryFileSystem(),
          makeDefault: true,
        );
        return WasmDatabase.inMemory(sqlite3);
      }
    } catch (_) {
      final result = await WasmDatabase.open(
        databaseName: 'gastosync_web',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      return result.resolvedExecutor;
    }
  });
}
