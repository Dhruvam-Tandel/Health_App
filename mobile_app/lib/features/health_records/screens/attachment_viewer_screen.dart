import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AttachmentViewerScreen extends StatefulWidget {
  final String url;
  
  const AttachmentViewerScreen({super.key, required this.url});

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  bool _isDownloading = false;

  Future<void> _shareImage() async {
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(Uri.parse(widget.url));
      final tempDir = await getTemporaryDirectory();
      
      // Determine file extension
      String ext = 'image.png';
      if (widget.url.toLowerCase().contains('.jpg') || widget.url.toLowerCase().contains('.jpeg')) ext = 'image.jpg';
      if (widget.url.toLowerCase().contains('.pdf')) ext = 'document.pdf';
      
      final file = File('${tempDir.path}/$ext');
      await file.writeAsBytes(response.bodyBytes);
      
      await Share.shareXFiles([XFile(file.path)], text: 'Shared from Smart Health Vault');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share/download: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _shareImage,
              tooltip: 'Share / Download',
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 4.0,
          child: Image.network(
             widget.url,
             fit: BoxFit.contain,
             loadingBuilder: (context, child, loadingProgress) {
               if (loadingProgress == null) return child;
               return const Center(child: CircularProgressIndicator(color: Colors.white));
             },
             errorBuilder: (context, error, stackTrace) => const Center(
               child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
             ),
          ),
        ),
      ),
    );
  }
}
