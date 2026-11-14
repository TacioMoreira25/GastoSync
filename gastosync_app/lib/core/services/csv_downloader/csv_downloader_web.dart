import 'dart:convert';
import 'dart:js_interop';

@JS('document.createElement')
external JSObject _createElement(JSString tagName);

extension type _AnchorElement(JSObject _) implements JSObject {
  external set href(JSString value);
  external set download(JSString value);
  external void click();
  external void remove();
}

Future<String?> downloadCsvFile({
  required String fileName,
  required String csvContent,
}) async {
  final bytes = utf8.encode(csvContent);
  final base64Data = base64Encode(bytes);
  final dataUrl = 'data:text/csv;charset=utf-8;base64,$base64Data';

  final anchor = _AnchorElement(_createElement('a'.toJS));
  anchor.href = dataUrl.toJS;
  anchor.download = fileName.toJS;
  anchor.click();
  anchor.remove();
  return fileName;
}
