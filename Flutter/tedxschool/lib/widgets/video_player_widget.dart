import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/mongodb_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String talkId;
  const VideoPlayerWidget({super.key, required this.talkId});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _tedxUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('TEDx loading: $url');
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            print('TEDx loaded: $url');
            setState(() => _isLoading = false);
          },
        ),
      );
    _loadTedx();
  }

  Future<void> _loadTedx() async {
    final talk = await MongoDBService.searchTalkById(widget.talkId);
    _tedxUrl = talk?['url'] ?? '';
    print('TEDx URL: $_tedxUrl');

    if (_tedxUrl != null) {
      await _controller.loadRequest(Uri.parse(_tedxUrl!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250, // ✅ Height FISSA no infinite
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Caricando TEDx...'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
