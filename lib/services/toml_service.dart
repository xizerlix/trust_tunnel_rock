import 'dart:io';
import '../models/vpn_server.dart';

class TomlService {
  static const String configFileName = 'trusttunnel_client.toml';
  static const String corePath = 'assets/core';

  static Future<File> getConfigFile() async {
    // Try multiple possible locations
    final possiblePaths = [
      // Relative paths
      File('$corePath/$configFileName'),
      File('./$corePath/$configFileName'),
      // Absolute paths based on current directory
      File('${Directory.current.path}/$corePath/$configFileName'),
      File('${Directory.current.path}\\$corePath\\$configFileName'),
      // Windows backslash version
      File('$corePath\\$configFileName'),
      // Try parent directory (in case we're in a subdirectory)
      File('../$corePath/$configFileName'),
      File('../../$corePath/$configFileName'),
    ];

    for (var file in possiblePaths) {
      if (await file.exists()) {
        print('[TomlService] Found config at: ${file.path}');
        return file;
      }
    }

    // If not found, return the default location
    final currentDir = Directory.current;
    final defaultFile = File('${currentDir.path}/$corePath/$configFileName');
    print(
      '[TomlService] No config found in any location, returning default: ${defaultFile.path}',
    );
    return defaultFile;
  }

  static Future<VpnServer?> loadServerFromToml() async {
    try {
      final configFile = await getConfigFile();
      print('[TomlService] Looking for config at: ${configFile.path}');

      if (!await configFile.exists()) {
        print('[TomlService] File does not exist: ${configFile.path}');
        return null;
      }

      print('[TomlService] Reading file: ${configFile.path}');
      final tomlContent = await configFile.readAsString();
      print('[TomlService] File content length: ${tomlContent.length}');
      print(
        '[TomlService] Content preview: ${tomlContent.substring(0, (tomlContent.length < 100 ? tomlContent.length : 100))}',
      );

      final server = VpnServer.fromToml(tomlContent);
      print('[TomlService] Parsed server: ${server?.name ?? "null"}');
      return server;
    } catch (e) {
      print('[TomlService] Error loading TOML: $e');
      return null;
    }
  }

  static Future<bool> saveServerToToml(VpnServer server) async {
    try {
      final configFile = await getConfigFile();
      print('[TomlService] Saving to: ${configFile.path}');
      await configFile.writeAsString(server.generateTomlConfig());
      print('[TomlService] Successfully saved config');
      return true;
    } catch (e) {
      print('[TomlService] Error saving TOML: $e');
      return false;
    }
  }

  static Future<bool> deleteConfigFile() async {
    try {
      final configFile = await getConfigFile();
      if (await configFile.exists()) {
        await configFile.delete();
      }
      return true;
    } catch (e) {
      print('Error deleting config: $e');
      return false;
    }
  }
}
