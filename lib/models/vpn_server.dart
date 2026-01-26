import 'dart:io';

class VpnServer {
  String name;
  String ipAddress;
  int port;
  String hostname;
  String username;
  String password;
  String protocol; // http2 or http3
  List<String> dnsServers;
  String vpnMode; // general or selective
  List<String> exclusions; // domains/IPs to bypass or route
  Process? process; // CLI process

  VpnServer({
    required this.name,
    required this.ipAddress,
    this.port = 443,
    required this.hostname,
    required this.username,
    required this.password,
    this.protocol = 'http2',
    this.dnsServers = const [],
    this.vpnMode = 'general',
    this.exclusions = const [],
    this.process,
  });

  // Generate TOML config content
  String generateTomlConfig() {
    final dnsUpstreams = dnsServers.isNotEmpty
        ? dnsServers.map((dns) => '\"$dns\"').join(', ')
        : '';

    final exclusionsList = exclusions.isNotEmpty
        ? exclusions.map((e) => '\"$e\"').join(', ')
        : '';

    return '''loglevel = "info"
vpn_mode = "$vpnMode"
killswitch_enabled = true
killswitch_allow_ports = []
post_quantum_group_enabled = false
exclusions = [${exclusionsList.isNotEmpty ? exclusionsList : ''}]

${dnsUpstreams.isNotEmpty ? 'dns_upstreams = [$dnsUpstreams]' : 'dns_upstreams = []'}

[endpoint]
hostname = "$hostname"
addresses = ["$ipAddress:$port"]
has_ipv6 = true
username = "$username"
password = "$password"
client_random = ""
skip_verification = true
certificate = ""
upstream_protocol = "$protocol"
upstream_fallback_protocol = ""
anti_dpi = false

[listener.tun]
bound_if = ""
included_routes = ["0.0.0.0/0", "2000::/3"]
excluded_routes = ["0.0.0.0/8", "10.0.0.0/8", "169.254.0.0/16", "172.16.0.0/12", "192.168.0.0/16", "224.0.0.0/3"]
mtu_size = 1500
change_system_dns = true
''';
  }

  // Save config to file
  Future<File?> saveConfigFile() async {
    try {
      final currentDir = Directory.current;
      final coreDir = Directory('${currentDir.path}/assets/core');

      if (!await coreDir.exists()) {
        await coreDir.create(recursive: true);
      }

      final configFile = File('${coreDir.path}/trusttunnel_client.toml');
      await configFile.writeAsString(generateTomlConfig());
      return configFile;
    } catch (e) {
      print('Error saving config: $e');
      return null;
    }
  }

  // Parse from TOML string
  static VpnServer? fromToml(String tomlContent) {
    try {
      print('[VpnServer.fromToml] Starting parse...');
      print('[VpnServer.fromToml] Content length: ${tomlContent.length}');

      // Extract vpn_mode
      final vpnModeRegex = RegExp(r'vpn_mode\s*=\s*"([^"]+)"');
      final vpnModeMatch = vpnModeRegex.firstMatch(tomlContent);
      final vpnMode = vpnModeMatch?.group(1) ?? 'general';
      print('[VpnServer.fromToml] vpn_mode: $vpnMode');

      // Extract exclusions array
      final exclusionsRegex = RegExp(
        r'exclusions\s*=\s*\[(.*?)\]',
        dotAll: true,
      );
      final exclusionsMatch = exclusionsRegex.firstMatch(tomlContent);
      final List<String> exclusions = [];
      if (exclusionsMatch != null && exclusionsMatch.group(1)!.isNotEmpty) {
        final items = exclusionsMatch.group(1)!.split(',');
        for (var item in items) {
          final cleaned = item.trim().replaceAll('"', '').trim();
          if (cleaned.isNotEmpty) exclusions.add(cleaned);
        }
      }
      print('[VpnServer.fromToml] exclusions: $exclusions');

      // Extract dns_upstreams array
      final dnsRegex = RegExp(r'dns_upstreams\s*=\s*\[(.*?)\]', dotAll: true);
      final dnsMatch = dnsRegex.firstMatch(tomlContent);
      final List<String> dnsServers = [];
      if (dnsMatch != null && dnsMatch.group(1)!.isNotEmpty) {
        final items = dnsMatch.group(1)!.split(',');
        for (var item in items) {
          final cleaned = item.trim().replaceAll('"', '').trim();
          if (cleaned.isNotEmpty) dnsServers.add(cleaned);
        }
      }
      print('[VpnServer.fromToml] dns_servers: $dnsServers');

      // Extract endpoint section - more robust regex
      // Match from [endpoint] to the next section header or end of string
      final endpointRegex = RegExp(
        r'\[endpoint\]\s*([\s\S]*?)(?=\n\[|\Z)',
        multiLine: true,
      );
      final endpointMatch = endpointRegex.firstMatch(tomlContent);
      if (endpointMatch == null) {
        print('[VpnServer.fromToml] ERROR: [endpoint] section not found');
        print('[VpnServer.fromToml] Full content: $tomlContent');
        return null;
      }

      final endpointContent = endpointMatch.group(1)!.trim();
      print(
        '[VpnServer.fromToml] endpoint content found (${endpointContent.length} chars)',
      );
      print('[VpnServer.fromToml] endpoint content:\n$endpointContent');

      // Extract individual endpoint fields
      final hostname = _extractTomlValue(endpointContent, 'hostname');
      final username = _extractTomlValue(endpointContent, 'username');
      final password = _extractTomlValue(endpointContent, 'password');
      final protocol = _extractTomlValue(endpointContent, 'upstream_protocol');

      print('[VpnServer.fromToml] hostname: "$hostname"');
      print('[VpnServer.fromToml] username: "$username"');
      print('[VpnServer.fromToml] protocol: "$protocol"');
      print('[VpnServer.fromToml] password: "$password"');

      // Extract addresses array to get IP and port
      final addressesRegex = RegExp(r'addresses\s*=\s*\[(.*?)\]');
      final addressesMatch = addressesRegex.firstMatch(endpointContent);
      String ipAddress = '';
      int port = 443;

      if (addressesMatch != null && addressesMatch.group(1)!.isNotEmpty) {
        final addressStr = addressesMatch.group(1)!.replaceAll('"', '').trim();
        print('[VpnServer.fromToml] address string: "$addressStr"');
        final parts = addressStr.split(':');
        if (parts.isNotEmpty) {
          ipAddress = parts[0].trim();
          if (parts.length > 1) {
            port = int.tryParse(parts[1].trim()) ?? 443;
          }
        }
      }
      print('[VpnServer.fromToml] ipAddress: "$ipAddress", port: $port');

      if (hostname.isEmpty || username.isEmpty) {
        print('[VpnServer.fromToml] ERROR: hostname or username is empty!');
        return null;
      }

      print('[VpnServer.fromToml] ✓ Successfully created VpnServer');
      return VpnServer(
        name: hostname,
        ipAddress: ipAddress,
        port: port,
        hostname: hostname,
        username: username,
        password: password,
        protocol: protocol.isNotEmpty ? protocol : 'http2',
        dnsServers: dnsServers,
        vpnMode: vpnMode,
        exclusions: exclusions,
      );
    } catch (e) {
      print('[VpnServer.fromToml] ERROR: $e');
      return null;
    }
  }

  // Helper to extract TOML value
  static String _extractTomlValue(String content, String key) {
    final regex = RegExp('$key\\s*=\\s*"([^"]+)"');
    final match = regex.firstMatch(content);
    final value = match?.group(1) ?? '';
    print('[VpnServer._extractTomlValue] key="$key" -> value="$value"');
    return value;
  }
}
