import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nearby_sync_utility_platform_interface.dart';

/// An implementation of [NearbySyncUtilityPlatform] that uses method channels.
class MethodChannelNearbySyncUtility extends NearbySyncUtilityPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nearby_sync_utility');
  final eventChannel = const EventChannel('nearby_sync_utility_events');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<bool> startAdvertising() async {
    final result = await methodChannel.invokeMethod<bool>(
      'startAdvertising',
    );
    return result ?? false;
  }

  @override
  Future<bool> stopAdvertising() async {
    final result = await methodChannel.invokeMethod<bool>('stopAdvertising');
    return result ?? false;
  }

  @override
  Future<bool> startDiscovery() async {
    final result = await methodChannel.invokeMethod<bool>('startDiscovery');
    return result ?? false;
  }

  @override
  Future<bool> stopDiscovery() async {
    final result = await methodChannel.invokeMethod<bool>('stopDiscovery');
    return result ?? false;
  }

  @override
  Future<bool> connectToDevice(String deviceId) async {
    final result = await methodChannel.invokeMethod<bool>(
      'connectToDevice',
      {'deviceId': deviceId},
    );
    return result ?? false;
  }

  @override
  Future<bool> disconnect(String deviceId) async {
    final result = await methodChannel.invokeMethod<bool>(
      'disconnect',
      {'deviceId': deviceId},
    );
    return result ?? false;
  }

  @override
  Future<bool> sendMessage(String deviceId, String message) async {
    final result = await methodChannel.invokeMethod<bool>(
      'sendMessage',
      {
        'deviceId': deviceId,
        'message': message,
      },
    );
    return result ?? false;
  }
}
