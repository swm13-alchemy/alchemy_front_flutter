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
  WebViewController? controller;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: SafeArea(
        child: Scaffold(
          body: WebView(
            onWebViewCreated: (WebViewController controller) {
              this.controller = controller;
            },
            initialUrl: 'https://alchemy-front-web.vercel.app/',
            javascriptMode: JavascriptMode.unrestricted,
          )
        )
      ),
      onWillPop: () {
        var future = controller!.canGoBack();
        future.then((cnaGoBack) {
          if (cnaGoBack) {
            controller!.goBack();
          } else {
            SystemNavigator.pop();
          }
        });
        return Future.value(false);
      }
    );
  }
}
// const Scaffold(
//   body: SafeArea(
//     child: WebView(
//       initialUrl: 'https://alchemy-front-web.vercel.app/',
//       javascriptMode: JavascriptMode.unrestricted,
//     )
//   )
// );