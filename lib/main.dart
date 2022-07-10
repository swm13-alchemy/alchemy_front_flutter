import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(
    const MaterialApp(
      home: WebViewApp(),
    ),
  );
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({Key? key}) : super(key: key);

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  @override
  Widget build(BuildContext context) {

    final double statusBarSize = MediaQuery.of(context).padding.top;

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Flutter WebView'),
      // ),
      body: SafeArea(
        child: const WebView(
          initialUrl: 'https://alchemy-front-web.vercel.app/',
        )
      )
    );
  }
}