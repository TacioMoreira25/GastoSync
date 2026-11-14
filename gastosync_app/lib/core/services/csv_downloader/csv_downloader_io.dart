import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> downloadCsvFile({
  required String fileName,
  required String csvContent,
}) async {
  final bytes = utf8.encode(csvContent);

  // 1. Em Android, tenta salvar diretamente na pasta pública Download se acessível
  if (Platform.isAndroid) {
    try {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (await publicDownloads.exists()) {
        final file = File(p.join(publicDownloads.path, fileName));
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      }
    } catch (_) {
      // Continua para os diretórios via path_provider
    }
  }

  // 2. Tenta o diretório de Downloads da plataforma (Windows, macOS, Linux, Android, iOS)
  try {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final file = File(p.join(downloadsDir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  } catch (_) {
    // Fallback abaixo
  }

  // 3. Em Android, tenta o diretório externo do app
  if (Platform.isAndroid) {
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final file = File(p.join(externalDir.path, fileName));
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      }
    } catch (_) {
      // Fallback abaixo
    }
  }

  // 4. Fallback universal: diretório de documentos do aplicativo
  final docsDir = await getApplicationDocumentsDirectory();
  final file = File(p.join(docsDir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
