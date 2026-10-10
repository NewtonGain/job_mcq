import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pdf_file_writer.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    required this.title,
    required this.assetPath,
    super.key,
  });

  final String title;
  final String assetPath;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _filePath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preparePdf();
  }

  Future<void> _preparePdf() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      if (kIsWeb) {
        if (!mounted) return;
        setState(() => _filePath = widget.assetPath);
        return;
      }
      final filePath = await preparePdfFile(
        widget.assetPath,
        data.buffer.asUint8List(),
      );
      if (!mounted) return;
      setState(() => _filePath = filePath);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not open this PDF: $error');
    }
  }

  Future<void> _openPdfInBrowser() async {
    final uri = Uri.base.resolve('assets/${widget.assetPath}');
    if (!await launchUrl(uri, webOnlyWindowName: '_blank') && mounted) {
      setState(() => _error = 'Could not open this PDF in the browser.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          )
        : _filePath == null
        ? const Center(child: CircularProgressIndicator())
        : kIsWeb
        ? Center(
            child: FilledButton.icon(
              onPressed: _openPdfInBrowser,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open PDF'),
            ),
          )
        : PDFView(
            filePath: _filePath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
          );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: content,
    );
  }
}
