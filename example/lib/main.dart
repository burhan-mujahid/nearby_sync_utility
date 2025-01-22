import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nearby_sync_utility/nearby_sync_utility.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NearbySyncUtility _nearby = NearbySyncUtility();
  final List<Map<String, String>> _discoveredDevices = [];
  final Set<String> _connectedDevices = {};
  bool _isAdvertising = false;
  bool _isDiscovering = false;


  @override
  void initState() {
    super.initState();
    _initializeNearby();
  }

  void _initializeNearby() {
    print("Initializing nearby connections");
    
    // Handle device discovery and incoming connections
    _nearby.onDeviceFound.listen((device) {
      print("Device found/connected: ${device['deviceName']} (${device['deviceId']})");
      if (mounted) {
        setState(() {
          // Remove any existing entries for this device ID
          _discoveredDevices.removeWhere((d) => d['deviceId'] == device['deviceId']);
          
          // Only add if it's a remote device
          if (device['isRemoteDevice'] == 'true') {
            _discoveredDevices.add(device);
            print("Added remote device to list: ${device['deviceName']}");
          }
        });
      }
    });

    // Handle connection state changes
    _nearby.onConnectionSuccess.listen((deviceId) {
      print("Connection success with device: $deviceId");
      if (mounted) {
        setState(() {
          _connectedDevices.add(deviceId);
        });
      }
    });

    _nearby.onDeviceDisconnected.listen((deviceId) {
      print("Device disconnected: $deviceId");
      if (mounted) {
        setState(() {
          _connectedDevices.remove(deviceId);
          // Remove the device from the list when disconnected
          _discoveredDevices.removeWhere((d) => d['deviceId'] == deviceId);
        });
      }
    });

    // Handle messages
    _nearby.onMessageReceived.listen((message) {
      if (mounted) {
        final deviceId = message['deviceId'] ?? '';
        // Find the device name from the discovered devices list
        final deviceName = _discoveredDevices
            .firstWhere(
              (d) => d['deviceId'] == deviceId,
              orElse: () => {'deviceName': 'Unknown Device'},
            )['deviceName'] ?? 'Unknown Device';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message from $deviceName: ${message['message']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }


  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      // Request WiFi permissions based on Android version
      final platformVersion = await _nearby.getPlatformVersion() ?? "0";
      final sdkVersion = int.tryParse(platformVersion) ?? 0;
      
      if (sdkVersion >= 33) {
        // For Android 13 and above
        final permissions = await [
          Permission.nearbyWifiDevices,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
        ].request();

        if (!permissions.values.every((status) => status.isGranted)) {
          permissions.forEach((permission, status) {
            print('Permission $permission is ${status.name}');
          });
          return false;
        }
      } else {
        // For Android 12L and below
        final locationStatus = await Permission.locationWhenInUse.request();
        if (!locationStatus.isGranted) {
          print('Location permission is ${locationStatus.name}');
          return false;
        }

        final bluetoothStatuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
        ].request();

        if (!bluetoothStatuses.values.every((status) => status.isGranted)) {
          bluetoothStatuses.forEach((permission, status) {
            print('Permission $permission is ${status.name}');
          });
          return false;
        }
      }

      return true;
    }
    return true; // For iOS
  }

  Future<void> _toggleAdvertising() async {
    if (!await _checkAndRequestPermissions()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Required permissions not granted'),
          ),
        );
      }
      return;
    }

    if (_isAdvertising) {
      print("Stopping advertising");
      await _nearby.stopAdvertising();
    } else {
      await _nearby.startAdvertising();
    }
    setState(() {
      _isAdvertising = !_isAdvertising;
    });
  }

  Future<void> _toggleDiscovery() async {
    if (!await _checkAndRequestPermissions()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Required permissions not granted')),
        );
      }
      return;
    }

    if (_isDiscovering) {
      print("Stopping discovery");
      await _nearby.stopDiscovery();
      setState(() {
        _isDiscovering = false;
        _discoveredDevices.clear();
        print("Cleared devices list");
      });
    } else {
      print("Starting discovery");
      setState(() {
        _discoveredDevices.clear();
        print("Cleared old devices before starting discovery");
      });
      await _nearby.startDiscovery();
      setState(() {
        _isDiscovering = true;
      });
    }
  }

  Future<void> _toggleConnection(String deviceId) async {
    try {
      if (_connectedDevices.contains(deviceId)) {
        await _nearby.disconnect(deviceId);
        setState(() {
          _connectedDevices.remove(deviceId);
        });
      } else {
        final connected = await _nearby.connectToDevice(deviceId);
        if (connected) {
          setState(() {
            _connectedDevices.add(deviceId);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage(String deviceId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Message'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _nearby.sendMessage(deviceId, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Sync Utility'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleAdvertising,
                  icon: Icon(_isAdvertising ? Icons.stop : Icons.broadcast_on_personal),
                  label: Text(_isAdvertising ? 'Stop Broadcasting' : 'Broadcast'),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleDiscovery,
                  icon: Icon(_isDiscovering ? Icons.stop : Icons.search),
                  label: Text(_isDiscovering ? 'Stop Discovery' : 'Discover'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: ListView.builder(
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  final deviceId = device['deviceId'] ?? '';
                  final deviceName = device['deviceName'] ?? 'Unknown Device';
                  final uniqueId = device['uniqueId'] ?? deviceId;
                  final isConnected = _connectedDevices.contains(deviceId);

                  return ListTile(
                    title: Text(deviceName),
                    subtitle: Text('ID: $uniqueId'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isConnected)
                          IconButton(
                            icon: const Icon(Icons.message),
                            onPressed: () => _sendMessage(deviceId),
                          ),
                        ElevatedButton(
                          onPressed: () => _toggleConnection(deviceId),
                          child: Text(isConnected ? 'Disconnect' : 'Connect'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nearby.dispose();
    super.dispose();
  }
}
