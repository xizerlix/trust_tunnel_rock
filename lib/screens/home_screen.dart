import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import '../controllers/app_controller.dart';
import '../widgets/window_drag_area.dart';
import 'add_edit_server_screen.dart';
import 'routing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
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
                    const Icon(
                      Icons.import_export,
                      size: 18,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'TrustTunnel',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
              tabs: const [
                Tab(text: 'Servers'),
                Tab(text: 'Routing'),
                Tab(text: 'Logs'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildServersTab(controller),
                  const RoutingScreen(),
                  _buildLogsTab(controller),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Obx(
        () => controller.tabIndex.value == 0
            ? FloatingActionButton(
                mini: true,
                onPressed: () => Get.to(() => const AddEditServerScreen()),
                child: const Icon(Icons.add),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildServersTab(AppController controller) {
    return Obx(
      () => controller.servers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.storage, size: 40, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No servers added yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: controller.servers.length,
              itemBuilder: (context, index) {
                final server = controller.servers[index];
                return Obx(() {
                  final isConnected =
                      controller.connectedServerIndex.value == index;
                  final isReady = controller.vpnConnectionReady.value;
                  final isActuallyConnected = isConnected && isReady;

                  return ListTile(
                    dense: true,
                    title: Text(server.name),
                    subtitle: Text(
                      server.hostname,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    leading: Icon(
                      Icons.circle,
                      size: 10,
                      color: isActuallyConnected ? Colors.green : Colors.grey,
                    ),
                    trailing: SizedBox(
                      width: 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: () => Get.to(
                              () => AddEditServerScreen(
                                initialServer: server,
                                serverIndex: index,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            onPressed: () => _showDeleteDialog(context, index),
                          ),
                          IconButton(
                            icon: Icon(
                              isActuallyConnected
                                  ? Icons.stop
                                  : Icons.play_arrow,
                              size: 16,
                            ),
                            color: isActuallyConnected
                                ? Colors.green
                                : Colors.blue,
                            onPressed: () => controller.toggleConnect(index),
                          ),
                        ],
                      ),
                    ),
                  );
                });
              },
            ),
    );
  }

  Widget _buildLogsTab(AppController controller) {
    return Obx(
      () => ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: controller.logs.length,
        itemBuilder: (context, index) => Text(
          controller.logs[index],
          style: const TextStyle(
            fontSize: 10,
            color: Colors.blueGrey,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int index) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Server'),
        content: Text(
          'Delete "${Get.find<AppController>().servers[index].name}"?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.find<AppController>().deleteServer(index);
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
