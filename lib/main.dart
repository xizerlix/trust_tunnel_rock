import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

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
  runApp(const MainApp());
}

class AppController extends GetxController {
  var connectedServerIndex = (-1).obs;
  var tabIndex = 0.obs; 
  var servers = <String>['Netherlands-1', 'Germany-Fast', 'USA-Entry'].obs;
  var logs = <String>["[System] App started"].obs;
  var routingText = "".obs;

  void toggleConnect(int index) {
    if (connectedServerIndex.value == index) {
      connectedServerIndex.value = -1;
      _addLog("Disconnected from ${servers[index]}");
    } else {
      connectedServerIndex.value = index;
      _addLog("Connecting to ${servers[index]}...");
    }
  }

  void _addLog(String message) {
    logs.insert(0, "[${DateTime.now().hour}:${DateTime.now().minute}] $message");
  }

  void addServer(String name) {
    if (name.isNotEmpty) {
      servers.add(name);
      _addLog("Added server: $name");
    }
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0F1214),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppController controller = Get.find<AppController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      controller.tabIndex.value = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            WindowDragArea(
              child: Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.black26,
                child: Row(
                  children: [
                    const Icon(Icons.import_export, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('TrustTunnel', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => windowManager.hide(),
                    ),
                  ],
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [Tab(text: 'Servers'), Tab(text: 'Routing'), Tab(text: 'Logs')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildServersTab(controller),
                  _buildRoutingTab(controller),
                  _buildLogsTab(controller),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Obx(() => controller.tabIndex.value == 0
          ? FloatingActionButton(
              mini: true,
              onPressed: () => _showAddServerDialog(context, controller),
              child: const Icon(Icons.add),
            )
          : const SizedBox.shrink()),
    );
  }

  Widget _buildServersTab(AppController controller) {
    return Obx(() => ListView.builder(
          itemCount: controller.servers.length,
          itemBuilder: (context, index) {
            final isConnected = controller.connectedServerIndex.value == index;
            return ListTile(
              dense: true,
              title: Text(controller.servers[index]),
              leading: Icon(Icons.circle, size: 10, color: isConnected ? Colors.green : Colors.grey),
              trailing: IconButton(
                icon: Icon(isConnected ? Icons.stop : Icons.play_arrow),
                color: isConnected ? Colors.green : Colors.blue,
                onPressed: () => controller.toggleConnect(index),
              ),
            );
          },
        ));
  }

  Widget _buildRoutingTab(AppController controller) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        maxLines: null,
        expands: true,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        decoration: const InputDecoration(
          hintText: 'Add IPs here...',
          filled: true,
          fillColor: Colors.black12,
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => controller.routingText.value = v,
      ),
    );
  }

  Widget _buildLogsTab(AppController controller) {
    return Obx(() => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: controller.logs.length,
          itemBuilder: (context, index) => Text(
            controller.logs[index],
            style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontFamily: 'monospace'),
          ),
        ));
  }

  void _showAddServerDialog(BuildContext context, AppController controller) {
    final textController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('Add Server'),
        content: TextField(controller: textController, decoration: const InputDecoration(hintText: 'Server name')),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              controller.addServer(textController.text);
              Get.back();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class WindowDragArea extends StatelessWidget {
  final Widget child;
  const WindowDragArea({super.key, required this.child});
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: child,
      );
}

class TrayControl extends TrayListener {
  TrayControl._();
  static final TrayControl instance = TrayControl._();
  Future<void> init() async {
    trayManager.addListener(this);
    await trayManager.setIcon(Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Show', onClick: (_) => windowManager.show()),
      MenuItem(key: 'exit', label: 'Exit', onClick: (_) => windowManager.close()),
    ]));
  }

  @override
  void onTrayIconMouseDown() => windowManager.isVisible().then((v) => v ? windowManager.hide() : windowManager.show());
  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();
}