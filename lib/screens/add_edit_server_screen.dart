import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/vpn_server.dart';
import '../controllers/app_controller.dart';

class AddEditServerScreen extends StatefulWidget {
  final VpnServer? initialServer;
  final int? serverIndex;

  const AddEditServerScreen({super.key, this.initialServer, this.serverIndex});

  @override
  State<AddEditServerScreen> createState() => _AddEditServerScreenState();
}

class _AddEditServerScreenState extends State<AddEditServerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _hostnameController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _dnsController;
  late String _selectedProtocol;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialServer?.name ?? '',
    );
    _ipController = TextEditingController(
      text: widget.initialServer?.ipAddress ?? '',
    );
    _portController = TextEditingController(
      text: '${widget.initialServer?.port ?? 443}',
    );
    _hostnameController = TextEditingController(
      text: widget.initialServer?.hostname ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.initialServer?.username ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.initialServer?.password ?? '',
    );
    _dnsController = TextEditingController(
      text: widget.initialServer?.dnsServers.join('\n') ?? '',
    );
    _selectedProtocol = widget.initialServer?.protocol ?? 'http2';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _hostnameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _dnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final isEditing = widget.initialServer != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit VPN Server' : 'Add VPN Server'),
        backgroundColor: Colors.black26,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Server Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'IP Address (VPN Server)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hostnameController,
                  decoration: const InputDecoration(
                    labelText: 'Domain Name (from cert)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedProtocol,
                  decoration: const InputDecoration(
                    labelText: 'Protocol',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'http2', child: Text('HTTP/2')),
                    DropdownMenuItem(value: 'http3', child: Text('QUIC')),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedProtocol = value ?? 'http2'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dnsController,
                  decoration: const InputDecoration(
                    labelText: 'DNS Servers (one per line)',
                    hintText: '8.8.8.8\n1.1.1.1',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 5,
                  maxLines: 10,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            final dnsServers = _dnsController.text
                                .split('\n')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();

                            final server = VpnServer(
                              name: _nameController.text,
                              ipAddress: _ipController.text,
                              port: int.tryParse(_portController.text) ?? 443,
                              hostname: _hostnameController.text,
                              username: _usernameController.text,
                              password: _passwordController.text,
                              protocol: _selectedProtocol,
                              dnsServers: dnsServers,
                            );

                            if (isEditing && widget.serverIndex != null) {
                              controller.updateServer(
                                widget.serverIndex!,
                                server,
                              );
                            } else {
                              controller.addServer(server);
                            }
                            Get.back();
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: Text(isEditing ? 'Update' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
