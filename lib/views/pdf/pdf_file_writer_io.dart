import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> preparePdfFile(String assetPath, List<int> bytes) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/${assetPath.split('/').last}');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
