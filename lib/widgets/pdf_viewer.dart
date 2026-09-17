import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:share_plus/share_plus.dart';

/// PDF Viewer widget using pdfrx package
class PdfViewer extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const PdfViewer({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  final pdfrx.PdfViewerController _controller = pdfrx.PdfViewerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePdf,
          ),
        ],
      ),
      body: pdfrx.PdfViewer.data(
        widget.pdfBytes,
        sourceName: 'pdf_viewer_${widget.fileName}',
        controller: _controller,
      ),
    );
  }

  Future<void> _sharePdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.pdfBytes);
      final shareParams = ShareParams(
        text: 'Tôi đang đọc: ${widget.fileName}',
        files: [XFile(file.path)],
      );
      await SharePlus.instance.share(shareParams);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chia sẻ: $e')),
      );
    }
  }
}
