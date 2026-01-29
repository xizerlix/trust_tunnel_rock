import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'dart:io';
import 'controllers/app_controller.dart';
import 'screens/home_screen.dart';
import 'services/tray_control.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Debug: Print current directory and search for config file
  print('====== DEBUG INFO ======');
  print('Current directory: ${Directory.current.path}');
  final possiblePaths = [
    'assets/core/trusttunnel_client.toml',
    './assets/core/trusttunnel_client.toml',
    '${Directory.current.path}/assets/core/trusttunnel_client.toml',
    '${Directory.current.path}\\assets\\core\\trusttunnel_client.toml',
  ];

  for (var path in possiblePaths) {
    final file = File(path);
    print('  $path -> ${await file.exists() ? "EXISTS ✓" : "NOT FOUND"}');
  }
  print('=======================');

  Get.put(AppController());

  double width = 300;
  double height = 450;

  WindowOptions windowOptions = WindowOptions(
    size: Size(width, height),
    minimumSize: Size(width, height),
    maximumSize: Size(width, height),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    Offset cursorPoint = await screenRetriever.getCursorScreenPoint();
    List<Display> displays = await screenRetriever.getAllDisplays();
    Display activeDisplay = primaryDisplay;

    for (var display in displays) {
      if (display.visiblePosition != null && display.visibleSize != null) {
        Rect bounds = Rect.fromLTWH(
          display.visiblePosition!.dx,
          display.visiblePosition!.dy,
          display.visibleSize!.width,
          display.visibleSize!.height,
        );
        if (bounds.contains(cursorPoint)) {
          activeDisplay = display;
          break;
        }
      }
    }

    Size workAreaSize = activeDisplay.visibleSize ?? activeDisplay.size;
    Offset workAreaOffset = activeDisplay.visiblePosition ?? Offset.zero;

    double x = workAreaOffset.dx + (workAreaSize.width - width - 20);
    double y = workAreaOffset.dy + (workAreaSize.height - height - 20);

    await windowManager.setPosition(Offset(x, y));
    await windowManager.show();
    await windowManager.focus();
  });

  await TrayControl.instance.init();
  if (await FlutterSingleInstance().isFirstInstance()) {
    runApp(const MainApp());
  } else {
    await windowManager.show();
    //await FlutterSingleInstance().focus();
    //await windowManager.focus();
    exit(0);
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1214),
      ),
      home: const HomeScreen(),
    );
  }
}
