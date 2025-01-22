import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_sync_utility/nearby_sync_utility.dart';
import 'package:nearby_sync_utility/nearby_sync_utility_platform_interface.dart';
import 'package:nearby_sync_utility/nearby_sync_utility_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNearbySyncUtilityPlatform
    with MockPlatformInterfaceMixin
    implements NearbySyncUtilityPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> startAdvertising() async => true;

  @override
  Future<bool> stopAdvertising() async => true;

  @override
  Future<bool> startDiscovery() async => true;

  @override
  Future<bool> stopDiscovery() async => true;

  @override
  Future<bool> connectToDevice(String deviceId) async => true;

  @override
  Future<bool> disconnect(String deviceId) async => true;

  @override
  Future<bool> sendMessage(String deviceId, String message) async => true;
}

void main() {
  final NearbySyncUtilityPlatform initialPlatform = NearbySyncUtilityPlatform.instance;

  test('$MethodChannelNearbySyncUtility is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNearbySyncUtility>());
  });

  test('getPlatformVersion', () async {
    NearbySyncUtility nearbySyncUtilityPlugin = NearbySyncUtility();
    MockNearbySyncUtilityPlatform fakePlatform = MockNearbySyncUtilityPlatform();
    NearbySyncUtilityPlatform.instance = fakePlatform;

    expect(await nearbySyncUtilityPlugin.getPlatformVersion(), '42');
  });

  test('startAdvertising returns true', () async {
    NearbySyncUtility nearbySyncUtilityPlugin = NearbySyncUtility();
    MockNearbySyncUtilityPlatform fakePlatform = MockNearbySyncUtilityPlatform();
    NearbySyncUtilityPlatform.instance = fakePlatform;

    expect(await nearbySyncUtilityPlugin.startAdvertising(), true);
  });

  test('stopAdvertising returns true', () async {
    NearbySyncUtility nearbySyncUtilityPlugin = NearbySyncUtility();
    MockNearbySyncUtilityPlatform fakePlatform = MockNearbySyncUtilityPlatform();
    NearbySyncUtilityPlatform.instance = fakePlatform;

    expect(await nearbySyncUtilityPlugin.stopAdvertising(), true);
  });

  test('startDiscovery returns true', () async {
    NearbySyncUtility nearbySyncUtilityPlugin = NearbySyncUtility();
    MockNearbySyncUtilityPlatform fakePlatform = MockNearbySyncUtilityPlatform();
    NearbySyncUtilityPlatform.instance = fakePlatform;

    expect(await nearbySyncUtilityPlugin.startDiscovery(), true);
  });

  test('stopDiscovery returns true', () async {
    NearbySyncUtility nearbySyncUtilityPlugin = NearbySyncUtility();
    MockNearbySyncUtilityPlatform fakePlatform = MockNearbySyncUtilityPlatform();
    NearbySyncUtilityPlatform.instance = fakePlatform;

    expect(await nearbySyncUtilityPlugin.stopDiscovery(), true);
  });

  test('connectToDevice returns true', () async {
    NearbySyncUtility nearbySyncUtilityPlugin = NearbySyncUtility();
    MockNearbySyncUtilityPlatform fakePlatform = MockNearbySyncUtilityPlatform();
    NearbySyncUtilityPlatform.instance = fakePlatform;

    expect(await nearbySyncUtilityPlugin.connectToDevice('test-device-id'), true);
  });

  test('disconnect returns true', () async {
    NearbySyncUtility nearbySyncUtilityPlugin = NearbySyncUtility();
    MockNearbySyncUtilityPlatform fakePlatform = MockNearbySyncUtilityPlatform();
    NearbySyncUtilityPlatform.instance = fakePlatform;

    expect(await nearbySyncUtilityPlugin.disconnect('test-device-id'), true);
  });

  test('sendMessage returns true', () async {
    NearbySyncUtility nearbySyncUtilityPlugin = NearbySyncUtility();
    MockNearbySyncUtilityPlatform fakePlatform = MockNearbySyncUtilityPlatform();
    NearbySyncUtilityPlatform.instance = fakePlatform;

    expect(await nearbySyncUtilityPlugin.sendMessage('test-device-id', 'test message'), true);
  });
}
