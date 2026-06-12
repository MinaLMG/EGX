import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/log_service.dart';

class DebugConsoleScreen extends StatefulWidget {
  @override
  _DebugConsoleScreenState createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  final _passwordController = TextEditingController();
  bool _isAuthenticated = false;
  bool _isLoading = false;

  Future<void> _verifyPassword() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/auth/debug-verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': _passwordController.text}),
      );

      if (response.statusCode == 200) {
        setState(() => _isAuthenticated = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Debug Password')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Debug Gate')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Enter Debug Password to view logs'),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyPassword,
                child: _isLoading 
                  ? const CircularProgressIndicator() 
                  : const Text('Unlock Console'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Logs'),
        backgroundColor: Colors.black,
        actions: [
          Switch(
            value: LogService.isEnabled,
            onChanged: (val) async {
              await LogService.toggle(val);
              setState(() {});
            },
            activeColor: Colors.greenAccent,
            inactiveTrackColor: Colors.red.withOpacity(0.3),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy),
            tooltip: 'Copy All Logs',
            onPressed: () {
              final allLogs = LogService.logHistory.reversed
                  .map((l) => '[${l['time']}] [${l['lvl']?.toUpperCase()}] ${l['msg']}')
                  .join('\n');
              Clipboard.setData(ClipboardData(text: allLogs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () => setState(() => LogService.logHistory.clear()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  LogService.isEnabled ? Icons.fiber_manual_record : Icons.pause_circle_filled,
                  color: LogService.isEnabled ? Colors.red : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  LogService.isEnabled ? 'RECORDER ACTIVE' : 'RECORDER PAUSED',
                  style: TextStyle(
                    color: LogService.isEnabled ? Colors.red : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: LogService.logHistory.length,
              itemBuilder: (context, index) {
                final log = LogService.logHistory[index];
                final color = log['lvl'] == 'error' ? Colors.redAccent : Colors.greenAccent;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('[${log['time']}] ', style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
                      Expanded(
                        child: Text(
                          log['msg'] ?? '',
                          style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
