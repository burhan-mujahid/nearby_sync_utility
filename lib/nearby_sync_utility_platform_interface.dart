import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nearby_sync_utility_method_channel.dart';

abstract class NearbySyncUtilityPlatform extends PlatformInterface {
  /// Constructs a NearbySyncUtilityPlatform.
  NearbySyncUtilityPlatform() : super(token: _token);

  static final Object _token = Object();

  static NearbySyncUtilityPlatform _instance = MethodChannelNearbySyncUtility();

  /// The default instance of [NearbySyncUtilityPlatform] to use.
  ///
  /// Defaults to [MethodChannelNearbySyncUtility].
  static NearbySyncUtilityPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NearbySyncUtilityPlatform] when
  /// they register themselves.
  static set instance(NearbySyncUtilityPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> startAdvertising() {
    throw UnimplementedError('startAdvertising() has not been implemented.');
  }

  Future<bool> stopAdvertising() {
    throw UnimplementedError('stopAdvertising() has not been implemented.');
  }

  Future<bool> startDiscovery() {
    throw UnimplementedError('startDiscovery() has not been implemented.');
  }

  Future<bool> stopDiscovery() {
    throw UnimplementedError('stopDiscovery() has not been implemented.');
  }

  Future<bool> connectToDevice(String deviceId) {
    throw UnimplementedError('connectToDevice() has not been implemented.');
  }

  Future<bool> disconnect(String deviceId) {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<bool> sendMessage(String deviceId, String message) {
    throw UnimplementedError('sendMessage() has not been implemented.');
  }
}
