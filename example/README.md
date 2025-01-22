# Nearby Sync Utility Example

This example demonstrates how to use the Nearby Sync Utility plugin to implement device discovery and peer-to-peer communication in a Flutter application.

## Features Demonstrated

* Device broadcasting (advertising)
* Nearby device discovery
* Establishing peer-to-peer connections
* Sending and receiving messages
* Permission handling for Android
* Connection state management

## Getting Started

1. Clone the repository
2. Navigate to the example directory
3. Run `flutter pub get` to install dependencies
4. Run the app on your test devices

## Required Permissions

### Android

Add these to your `AndroidManifest.xml`:

```xml
<!-- Feature declarations -->
<uses-feature android:name="android.hardware.bluetooth" android:required="true" />
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
<uses-feature android:name="android.hardware.wifi" android:required="true" />

<!-- Location Permissions (Android 12 and below) -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" 
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
    android:maxSdkVersion="32" />

<!-- Bluetooth Permissions -->
<uses-permission android:name="android.permission.BLUETOOTH" 
    android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" 
    android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- WiFi Permissions -->
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES"
    android:usesPermissionFlags="neverForLocation" />
```

### Dependencies

Add these to your `pubspec.yaml`:
```yaml
dependencies:
  nearby_sync_utility: ^0.0.1  # Use latest version
  permission_handler: ^11.0.0
```

## Usage Example

```dart
// Initialize the plugin
final nearby = NearbySyncUtility();

// Set up event listeners
nearby.onDeviceFound.listen((device) {
  print("Device found: ${device['deviceName']}");
});

nearby.onConnectionSuccess.listen((deviceId) {
  print("Connected to device: $deviceId");
});

nearby.onMessageReceived.listen((message) {
  print("Message from ${message['deviceId']}: ${message['message']}");
});

// Start broadcasting your device
await nearby.startAdvertising();

// Start discovering other devices
await nearby.startDiscovery();

// Connect to a device
await nearby.connectToDevice(deviceId);

// Send a message
await nearby.sendMessage(deviceId, "Hello!");

// Clean up
nearby.dispose();
```

## Key Implementation Details

1. **Permission Handling**: The example handles runtime permissions for different Android versions:
    * Location permissions for Android 12 and below
    * Bluetooth permissions for different SDK versions
    * WiFi permissions including the new NEARBY_WIFI_DEVICES permission

2. **Device Discovery**: Uses a `ListView` to display discovered devices with their connection status.

3. **Connection Management**: Demonstrates how to:
    * Connect/disconnect to devices
    * Track connection states
    * Handle connection errors

4. **Message Exchange**: Shows implementation of:
    * Sending messages through a dialog
    * Receiving and displaying messages via snackbars

## Important Notes

* Always call `dispose()` when the plugin is no longer needed
* Ensure correct permission handling based on Android SDK version
* Test on actual devices, as emulators may not fully support all features
* Keep track of connection states to prevent sending messages to disconnected devices
* Location services must be enabled on Android 12 and below devices

## Troubleshooting

Common issues and solutions:

1. **Devices not discovering**:
    * For Android 12 and below: Ensure location permissions are granted and location services are enabled
    * For Android 13+: Verify NEARBY_WIFI_DEVICES and Bluetooth permissions are granted

2. **Connection failures**:
    * Verify both devices have the app in the foreground
    * Check if all required feature declarations are present in AndroidManifest.xml
    * Ensure both Bluetooth and WiFi are enabled

3. **Permission errors**:
    * Double-check that your AndroidManifest.xml includes all required permissions with correct maxSdkVersion and usesPermissionFlags attributes
    * Verify runtime permission requests are handling all required permissions

## Testing

To test the example:

1. Install the app on two or more devices
2. Start advertising on one device
3. Start discovery on another device
4. Attempt to connect the devices
5. Try sending messages between connected devices

The example UI provides feedback for all operations through snackbar messages and visual indicators.

The example automatically handles permission requests at runtime through the `_checkAndRequestPermissions()` method, which ensures all necessary permissions are granted before starting device discovery or advertising.