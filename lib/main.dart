import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

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

class _WebViewAppState extends State<WebViewApp> with WidgetsBindingObserver {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this); // 앱 아이콘 뱃지 초기화
    _init();  // local_notification 초기화
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);  // 앱 아이콘 뱃지 초기화
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FlutterAppBadger.removeBadge(); // 앱 아이콘 뱃지 초기화
    }
  }

  Future<void> _init() async {  // local_notification 초기화
    await _configureLocalTimeZone();  // 현재 단말기의 현재 시간 등록
    await _initializeNotification();
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String? timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName!));
  }

  Future<void> _initializeNotification() async {
    // Android 메시지 권한 요청 초기화 (푸시 메시지 아이콘은 ./android/app/src/main/res/drawable 에 저장)
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('mipmap/ic_launcher');

    // iOS 메시지 권한 요청 초기화 (flutter_local_notification 11.0.0부터 IOSInitializationSettings -> DarwinInitializationSettings으로 이름 바뀜)
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  /// 이전에 등록된 모든 메시지 취소 함수
  Future<void> _cancelAllNotification() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// 파라매터로 받은 id의 메시지만 취소하는 함수
  Future<void> _cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// iOS의 푸시 메시지 권한 요청하는 함수 (한 번 확인하면 다시 권한을 요청하지 않음)
  Future<void> _requestPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// 주간으로 알림을 보내주는 함수
  Future<void> _addWeeklyNotification({
    required int pillId,
    required List<int> intakeDays,
    required List<List<int>> intakeTimes,
    required String message,
  }) async {
    // tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, year, month, day, hour, minutes);
    // final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    // // 오늘보다 이전 날짜인 경우 7일후로 알림 변경 (이 방식으로 일주일마다 알림을 줌)
    // if (scheduledDate.isBefore(now)) {
    //   scheduledDate.add(Duration(days: 7));
    // }

    final android = AndroidNotificationDetails(
        pillId.toString(),
        '영양제 복용 알림 채널',
        channelDescription: '매일 영양제 복용 알림을 주는 채널입니다.',
        importance: Importance.max,
        priority: Priority.high,
        ongoing: false, // true로 하면 앱을 실행해야만 메시지가 사라짐
        styleInformation: BigTextStyleInformation(message),
        icon: 'ic_notification'
    );

    final ios = DarwinNotificationDetails(badgeNumber: 1); // 11.0.0 부터 IOSNotificationDetails -> DarwinNotificationDetails

    final detail = NotificationDetails(android: android, iOS: ios);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      pillId,
      '영양제 섭취 시간 알림',
      message,
      _nextInstanceOfTime(intakeDays, intakeTimes), // 알림 시간을 맞추는 함수 (여기가 핵심)
      detail,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// 다음 알림이 울려야 할 적절한 '시간'을 찾는 함수 (_nextInstanceOfDateTime 함수를 호출)
  tz.TZDateTime _nextInstanceOfTime(List<int> intakeDays, List<List<int>> intakeTimes) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = _nextInstanceOfDateTime(intakeDays, now);

    // 받아온 scheduledDate가 현재 날짜보다 미래라면 intakeTimes 리스트의 첫번째 인덱스 값을 시간, 분으로 하여 알림등록
    if (scheduledDate.isAfter(now)) {
      scheduledDate = tz.TZDateTime(tz.local, scheduledDate.year, scheduledDate.month, scheduledDate.day, intakeTimes[0][0], intakeTimes[0][1]);
    }

    var idx = 0;
    // scheduledDate가 오늘이라면, 현재 시간보다 앞서도록 시간, 분을 수정
    while (scheduledDate.isBefore(now)) {
      // 만약 idx 값이 intakeTimes의 개수를 넘는다면, (오늘 하루 울릴 알림이 다 울린 상태인 경우) 다음 울릴 날짜를 찾음
      if (idx >= intakeTimes.length) {
        do {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        } while (!intakeDays.contains(scheduledDate.weekday));

        // 찾았으면 해당 날짜에 intakeTimes 리스트의 첫번째 인덱스 값을 시간, 분으로 하여 알림등록
        scheduledDate = tz.TZDateTime(tz.local, scheduledDate.year, scheduledDate.month, scheduledDate.day, intakeTimes[0][0], intakeTimes[0][1]);
        break;
      }

      // idx 값이 intakeTimes의 개수를 넘지 않는 경우 intakeTimes의 값들을 순회하며 시간, 분 값을 수정해봄
      scheduledDate = tz.TZDateTime(tz.local, scheduledDate.year, scheduledDate.month, scheduledDate.day, intakeTimes[idx][0], intakeTimes[idx][1]);
    }

    return scheduledDate;
  }

  /// 다음 알림이 울려야 할 적절한 '날짜'를 찾는 함수
  tz.TZDateTime _nextInstanceOfDateTime(List<int> intakeDays, tz.TZDateTime now) {
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    // 현재 scheduledDate의 날짜가 days 리스트에 해당하는 요일이 아니거나, 오늘보다 이전의 날짜일 경우 하루를 계속해서 더함 (이 로직으로 지정된 요일에 알림을 줌)
    while (!intakeDays.contains(scheduledDate.weekday) ||
        (scheduledDate.isBefore(now) && !(scheduledDate.year == now.year && scheduledDate.month == now.month && scheduledDate.day == now.day))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// 카메라에 대한 권한을 얻는 함수
  Future<bool> requestCameraPermission() async {
    Map<Permission, PermissionStatus> statuses =
    await [Permission.storage, Permission.camera].request();

    if (await Permission.camera.isGranted &&
        await Permission.storage.isGranted) {
      return Future.value(true);
    } else {
      return Future.value(false);
    }
  }


  WebViewController? _controller;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        child: SafeArea(
            child: Scaffold(
                body: WebView(
                  onWebViewCreated: (WebViewController controller) {
                    this._controller = controller;
                  },
                  initialUrl: 'https://alchemy-front-web.vercel.app/',
                  javascriptMode: JavascriptMode.unrestricted,
                  javascriptChannels: { // javascript bridge
                    // 알림 추가 채널
                    JavascriptChannel(
                        name: 'AddWeeklyNotification',
                        onMessageReceived: (JavascriptMessage message) async {
                          await _requestPermissions();

                          var data = jsonDecode(message.message);

                          await _addWeeklyNotification(
                              pillId: data['pillId'],
                              intakeDays: data['intakeDays'],
                              intakeTimes: data['intakeTimes'],
                              message: data['message']
                          );
                        }
                    ),
                    // 알림 편집 채널
                    JavascriptChannel(
                        name: 'EditWeeklyNotification',
                        onMessageReceived: (JavascriptMessage message) async {
                          await _requestPermissions();

                          var data = jsonDecode(message.message);

                          await _cancelNotification(data['pillId']) // 기존 알림 삭제 후, 새로 만듦 (수정이 따로 없음)
                              .then((value) => _addWeeklyNotification(
                              pillId: data['pillId'],
                              intakeDays: data['intakeDays'],
                              intakeTimes: data['intakeTimes'],
                              message: data['message']
                          ));
                        }
                    ),
                    // 알림 삭제 채널
                    JavascriptChannel(
                      name: 'DeleteWeeklyNotification',
                      onMessageReceived: (JavascriptMessage message) async {
                        var data = jsonDecode(message.message);

                        await _cancelNotification(data['pillId']);
                      }
                    ),
                    // 필렌즈 카메라, 앨범 접근 권한 얻기 채널
                    JavascriptChannel(
                      name: 'RequestCameraPermission',
                      onMessageReceived: (JavascriptMessage message) async {
                        await requestCameraPermission()
                            .then((value) => {
                              if (value) {
                                /// TODO: 이거 추후 permission 허용 했을 때 페이지 넘어가도록 처리 해야함.. 현재 runJavascript가 안먹힘...
                                // _controller!.runJavascript('')
                              }
                        });
                      }
                    )
                  },
                )
            )
        ),
        onWillPop: () {
          var future = _controller!.canGoBack();
          future.then((cnaGoBack) {
            if (cnaGoBack) {
              _controller!.goBack();
            } else {
              SystemNavigator.pop();
            }
          });
          return Future.value(false);
        }
    );
  }
}