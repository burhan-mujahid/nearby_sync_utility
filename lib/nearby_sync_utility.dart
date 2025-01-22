import 'dart:async';
import 'package:flutter/services.dart';
import 'nearby_sync_utility_platform_interface.dart';

class NearbySyncUtility {
  // Singleton instance
  static final NearbySyncUtility _instance = NearbySyncUtility._internal();
  factory NearbySyncUtility() => _instance;
  NearbySyncUtility._internal() {
    _initializePlatformEvents();
  }

  // Stream controllers for device discovery and messages
  final _deviceStreamController = StreamController<Map<String, String>>.broadcast();
  final _messageStreamController = StreamController<Map<String, String>>.broadcast();
  final _deviceLostStreamController = StreamController<String>.broadcast();
  final _connectionStreamController = StreamController<String>.broadcast();
  final _disconnectionStreamController = StreamController<String>.broadcast();

  // Getters for streams
  Stream<Map<String, String>> get onDeviceFound => _deviceStreamController.stream;
  Stream<Map<String, String>> get onMessageReceived => _messageStreamController.stream;
  Stream<String> get onDeviceLost => _deviceLostStreamController.stream;
  Stream<String> get onConnectionSuccess => _connectionStreamController.stream;
  Stream<String> get onDeviceDisconnected => _disconnectionStreamController.stream;

  Future<String?> getPlatformVersion() {
    return NearbySyncUtilityPlatform.instance.getPlatformVersion();
  }

  // Start advertising this device
  Future<bool> startAdvertising() async {
    return await NearbySyncUtilityPlatform.instance.startAdvertising();
  }

  // Stop advertising
  Future<bool> stopAdvertising() async {
    return await NearbySyncUtilityPlatform.instance.stopAdvertising();
  }

  // Start discovering nearby devices
  Future<bool> startDiscovery() async {
    return await NearbySyncUtilityPlatform.instance.startDiscovery();
  }

  // Stop discovering
  Future<bool> stopDiscovery() async {
    return await NearbySyncUtilityPlatform.instance.stopDiscovery();
  }

  // Connect to a device
  Future<bool> connectToDevice(String deviceId) async {
    try {
      return await NearbySyncUtilityPlatform.instance.connectToDevice(deviceId);
    } catch (e) {
      print("Connection error: $e");
      // Attempt recovery
      await stopDiscovery();
      await Future.delayed(const Duration(milliseconds: 500));
      await startDiscovery();
      rethrow;
    }
  }

  // Disconnect from a device
  Future<bool> disconnect(String deviceId) async {
    return await NearbySyncUtilityPlatform.instance.disconnect(deviceId);
  }

  // Send message to connected device
  Future<bool> sendMessage(String deviceId, String message) async {
    return await NearbySyncUtilityPlatform.instance.sendMessage(deviceId, message);
  }

  // Dispose resources
  void dispose() {
    _deviceStreamController.close();
    _messageStreamController.close();
    _deviceLostStreamController.close();
    _connectionStreamController.close();
    _disconnectionStreamController.close();
  }

  // Add this method to handle incoming events
  void _handlePlatformEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      final deviceId = event['deviceId'] as String?;
      final deviceName = event['deviceName'] as String? ?? 'Unknown Device';
      final isRemoteDevice = event['isRemoteDevice'] as bool? ?? false;
      
      if (deviceId == null) return;

      switch (type) {
        case 'deviceFound':
          if (!_deviceNames.containsKey(deviceId)) {
            final deviceInfo = {
              'deviceId': deviceId,
              'deviceName': deviceName,
              'uniqueId': event['uniqueId'] as String? ?? deviceId,
              'isRemoteDevice': isRemoteDevice.toString(),
            };
            _deviceStreamController.add(deviceInfo);
            _deviceNames[deviceId] = deviceName;
          }
          break;
        case 'connectionSuccess':
          _connectionStreamController.add(deviceId);
          _connectionStates[deviceId] = true;
          // Update device name if available
          if (event['deviceName'] != null) {
            _deviceNames[deviceId] = event['deviceName'] as String;
          }
          break;
        case 'connectionFailed':
          print("Connection failed: ${event['error']}");
          _connectionStates[deviceId] = false;
          break;
        case 'deviceLost':
          _deviceLostStreamController.add(deviceId);
          _connectionStates[deviceId] = false;
          break;
        case 'deviceDisconnected':
          _disconnectionStreamController.add(deviceId);
          _connectionStates[deviceId] = false;
          break;
        case 'messageReceived':
          _messageStreamController.add({
            'deviceId': deviceId,
            'deviceName': _deviceNames[deviceId] ?? deviceName, // Use stored name
            'message': event['message'] as String? ?? 'No message',
          });
          break;
      }
    }
  }

  // Initialize platform event channel
  void _initializePlatformEvents() {
    const eventChannel = EventChannel('nearby_sync_utility_events');
    eventChannel.receiveBroadcastStream().listen(
      _handlePlatformEvent,
      onError: (error) {
        print('Error from platform events: $error');
      },
    );
  }

  // Add connection state tracking
  final Map<String, bool> _connectionStates = {};
  
  bool isDeviceConnected(String deviceId) {
    return _connectionStates[deviceId] ?? false;
  }

  // Add a map to store device names
  final Map<String, String> _deviceNames = {};
}
