import 'dart:io';
import 'dart:convert';
import 'package:get/get.dart';
import '../models/vpn_server.dart';
import '../controllers/app_controller.dart';

typedef LogCallback = void Function(String message);

class VpnService {
  static Future<void> startVpnProcess(
    VpnServer server,
    LogCallback onLog,
  ) async {
    try {
      final currentDir = Directory.current;
      final exePath =
          '${currentDir.path}\\assets\\core\\trusttunnel_client.exe';
      final configPath =
          '${currentDir.path}\\assets\\core\\trusttunnel_client.toml';

      onLog("[System] Starting VPN client...");
      onLog("[System] Exe path: $exePath");
      onLog("[System] Config path: $configPath");

      if (!await File(exePath).exists()) {
        onLog("[ERROR] VPN client executable not found: $exePath");
        return;
      }

      if (!await File(configPath).exists()) {
        onLog("[ERROR] Config file not found: $configPath");
        return;
      }

      final process = await Process.start(exePath, [
        '--config',
        configPath,
      ], runInShell: false);

      server.process = process;
      onLog("[System] VPN client process started with PID: ${process.pid}");

      // Listen to stdout
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
            if (line.isNotEmpty) {
              final trimmedLine = line.trim();
              onLog(trimmedLine);

              // Update VPN status via AppController
              try {
                final controller = Get.find<AppController>();
                controller.updateVpnStatus(trimmedLine);
              } catch (e) {
                // Controller not available yet
              }
            }
          });

      // Listen to stderr
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
            if (line.isNotEmpty) {
              final trimmedLine = line.trim();
              onLog("[STDERR] $trimmedLine");

              // Also update VPN status from stderr!
              try {
                final controller = Get.find<AppController>();
                controller.updateVpnStatus(trimmedLine);
              } catch (e) {
                // Controller not available yet
              }
            }
          });

      // Handle process exit
      process.exitCode.then((code) {
        onLog("[System] VPN client exited with code: $code");
        if (code != 0) {
          onLog("[ERROR] VPN process exited with non-zero code!");
        }
        server.process = null;
      });
    } catch (e) {
      onLog("[System] Failed to start VPN client: $e");
    }
  }

  static Future<void> stopVpnProcess(
    VpnServer server,
    LogCallback onLog,
  ) async {
    try {
      if (server.process != null) {
        server.process?.kill();
        server.process = null;
        onLog("[System] VPN client stopped");
      }
    } catch (e) {
      onLog("[System] Error stopping VPN client: $e");
    }
  }
}
