import 'package:get/get.dart';
import 'dart:io';
import '../models/vpn_server.dart';
import '../services/toml_service.dart';
import '../services/vpn_service.dart';

class AppController extends GetxController {
  var connectedServerIndex = (-1).obs;
  var tabIndex = 0.obs;
  var servers = <VpnServer>[].obs;
  var logs = <String>["[System] App started"].obs;
  var vpnMode = 'general'.obs;
  var exclusions = <String>[].obs;
  var vpnConnectionReady = false.obs;  // true when "vpn_listen: [0] Done" received

  @override
  void onInit() {
    super.onInit();
    _killExistingVpnProcess();
    _loadServer();
  }

  Future<void> _killExistingVpnProcess() async {
    try {
      _addLog("[System] Checking for existing trusttunnel processes...");
      final result = await Process.run('tasklist', []);
      final output = result.stdout.toString();
      
      if (output.contains('trusttunnel_client.exe')) {
        _addLog("[System] Found existing trusttunnel process, killing it...");
        await Process.run('taskkill', ['/IM', 'trusttunnel_client.exe', '/F']);
        _addLog("[System] ✓ Existing process killed");
        await Future.delayed(const Duration(seconds: 1));
      } else {
        _addLog("[System] No existing trusttunnel process found");
      }
    } catch (e) {
      _addLog("[System] Error checking for existing process: $e");
    }
  }

  Future<void> _loadServer() async {
    try {
      _addLog("[System] Loading server from TOML...");
      final server = await TomlService.loadServerFromToml();
      if (server != null) {
        servers.add(server);
        _addLog("[System] ✓ Loaded server: ${server.name}");
      } else {
        _addLog("[System] No server found in trusttunnel_client.toml");
      }
    } catch (e) {
      _addLog("[System] Error loading server: $e");
    }
  }

  void toggleConnect(int index) {
    if (connectedServerIndex.value == index) {
      connectedServerIndex.value = -1;
      vpnConnectionReady.value = false;
      _stopVpnProcess(index);
      _addLog("Disconnecting from ${servers[index].name}...");
    } else {
      connectedServerIndex.value = index;
      vpnConnectionReady.value = false;  // reset until we get "Done" message
      loadServerRouting(index);
      _addLog("Connecting to ${servers[index].name}...");
      // Kill any existing trusttunnel process before starting new one
      _killExistingVpnProcess().then((_) {
        _startVpnProcess(index);
      });
    }
  }

  Future<void> _startVpnProcess(int index) async {
    if (index < 0 || index >= servers.length) return;

    final server = servers[index];
    await TomlService.saveServerToToml(server);
    await VpnService.startVpnProcess(server, _addLog);
  }

  Future<void> _stopVpnProcess(int index) async {
    if (index < 0 || index >= servers.length) return;
    await VpnService.stopVpnProcess(servers[index], _addLog);
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    logs.insert(0, "[$hour:$minute] $message");
  }

  Future<void> addServer(VpnServer server) async {
    servers.add(server);
    await TomlService.saveServerToToml(server);
    _addLog("Added server: ${server.name}");
  }

  Future<void> updateServer(int index, VpnServer updatedServer) async {
    if (index < 0 || index >= servers.length) return;
    servers[index] = updatedServer;
    await TomlService.saveServerToToml(updatedServer);
    _addLog("Updated server: ${updatedServer.name}");
  }

  Future<void> deleteServer(int index) async {
    if (index < 0 || index >= servers.length) return;
    final serverName = servers[index].name;

    if (connectedServerIndex.value == index) {
      await _stopVpnProcess(index);
      connectedServerIndex.value = -1;
      vpnConnectionReady.value = false;
    }

    servers.removeAt(index);

    if (servers.isNotEmpty) {
      await TomlService.saveServerToToml(servers[0]);
    } else {
      await TomlService.deleteConfigFile();
    }

    _addLog("Deleted server: $serverName");
  }

  void setVpnMode(String mode) {
    vpnMode.value = mode;
    if (connectedServerIndex.value >= 0) {
      servers[connectedServerIndex.value].vpnMode = mode;
      _saveCurrentServerConfig();
    }
  }

  void addExclusion(String exclusion) {
    if (exclusion.isNotEmpty && !exclusions.contains(exclusion)) {
      exclusions.add(exclusion);
      if (connectedServerIndex.value >= 0) {
        servers[connectedServerIndex.value].exclusions = List.from(exclusions);
        _saveCurrentServerConfig();
      }
    }
  }

  void removeExclusion(String exclusion) {
    exclusions.remove(exclusion);
    if (connectedServerIndex.value >= 0) {
      servers[connectedServerIndex.value].exclusions = List.from(exclusions);
      _saveCurrentServerConfig();
    }
  }

  Future<void> _saveCurrentServerConfig() async {
    if (connectedServerIndex.value >= 0) {
      await TomlService.saveServerToToml(servers[connectedServerIndex.value]);
      _addLog("[System] Routing config updated");
    }
  }

  void loadServerRouting(int index) {
    if (index >= 0 && index < servers.length) {
      vpnMode.value = servers[index].vpnMode;
      exclusions.value = servers[index].exclusions;
    }
  }

  void updateVpnStatus(String message) {
    // Check if VPN is fully ready and listening - THIS IS THE SUCCESS SIGNAL
    if (message.contains('vpn_listen: [0] Done')) {
      print('DEBUG: Found vpn_listen Done signal: $message');
      vpnConnectionReady.value = true;
      _addLog("[System] ✓ VPN connection is ready!");
      return; // Early return to avoid overriding with other checks
    }
    
    // Check if connection is lost (waiting for recovery)
    if (message.contains('VPN_SS_WAITING_RECOVERY') || 
        message.contains('VPN_SS_RECOVERING')) {
      vpnConnectionReady.value = false;
      _addLog("[System] ⚠ Connection unstable, attempting recovery...");
      return;
    }
    
    // Check for hard connection loss
    if (message.contains('Failed to connect to endpoint')) {
      vpnConnectionReady.value = false;
      _addLog("[System] ✗ Connection lost - trying to reconnect...");
      return;
    }
  }
}
