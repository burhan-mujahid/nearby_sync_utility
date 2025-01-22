package com.burhan.nearby_sync_utility.nearby_sync_utility

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NearbySyncUtilityPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var connectionsClient: ConnectionsClient
    private val SERVICE_ID = "com.burhan.nearby_sync_utility.service"
    
    private val advertisingOptions = AdvertisingOptions.Builder()
        .setStrategy(Strategy.P2P_STAR)
        .build()

    private val discoveryOptions = DiscoveryOptions.Builder()
        .setStrategy(Strategy.P2P_STAR)
        .build()

    private val REQUIRED_PERMISSIONS = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.NEARBY_WIFI_DEVICES,
            Manifest.permission.ACCESS_WIFI_STATE,
            Manifest.permission.CHANGE_WIFI_STATE
        )
    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_WIFI_STATE,
            Manifest.permission.CHANGE_WIFI_STATE
        )
    } else {
        arrayOf(
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_WIFI_STATE,
            Manifest.permission.CHANGE_WIFI_STATE
        )
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "nearby_sync_utility")
        channel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(binding.binaryMessenger, "nearby_sync_utility_events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d("NearbySyncUtility", "EventChannel: onListen called")
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                Log.d("NearbySyncUtility", "EventChannel: onCancel called")
                eventSink = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Plugin requires a foreground activity", null)
            return
        }

        when (call.method) {
            "getPlatformVersion" -> {
                result.success(Build.VERSION.SDK_INT.toString())
            }
            "checkPermissions" -> {
                result.success(hasPermissions())
            }
            "requestPermissions" -> {
                if (hasPermissions()) {
                    result.success(true)
                } else {
                    requestPermissions()
                    result.success(false)
                }
            }
            "startAdvertising" -> {
                if (!hasPermissions()) {
                    result.error("PERMISSION_DENIED", "Required permissions not granted", null)
                    return
                }
//                val deviceName = call.argument<String>("deviceName")
//                if (deviceName == null) {
//                    result.error("INVALID_ARGUMENT", "Device name is required", null)
//                    return
//                }
                startAdvertising(result)
            }
            "stopAdvertising" -> stopAdvertising(result)
            "startDiscovery" -> {
                if (!hasPermissions()) {
                    result.error("PERMISSION_DENIED", "Required permissions not granted", null)
                    return
                }
                startDiscovery(result)
            }
            "stopDiscovery" -> stopDiscovery(result)
            "connectToDevice" -> connectToDevice(call.argument("deviceId")!!, result)
            "disconnect" -> disconnect(call.argument("deviceId")!!, result)
            "sendMessage" -> sendMessage(
                call.argument("deviceId")!!,
                call.argument("message")!!,
                result
            )
            else -> result.notImplemented()
        }
    }

    private fun getDeviceName(): String {
        return try {
            val manufacturer = Build.MANUFACTURER
            val model = Build.MODEL
            if (model.startsWith(manufacturer, ignoreCase = true)) {
                model.capitalize()
            } else {
                "${manufacturer.capitalize()} $model"
            }
        } catch (e: Exception) {
            "Unknown Device"
        }
    }

    private fun startAdvertising(result: Result) {
        if (!hasPermissions()) {
            result.error("PERMISSION_DENIED", "Required permissions not granted", null)
            return
        }

        val deviceName = getDeviceName()

//        val actualDeviceName = "$deviceName#${System.currentTimeMillis()}"
        connectionsClient.startAdvertising(
            deviceName,
            SERVICE_ID,
            connectionLifecycleCallback,
            advertisingOptions
        ).addOnSuccessListener {
            result.success(true)
        }.addOnFailureListener {
            result.error("ADVERTISING_FAILED", it.message, null)
        }
    }

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            Log.d("NearbySyncUtility", "Connection initiated with: $endpointId, name: ${info.endpointName}")
            connectionsClient.acceptConnection(endpointId, payloadCallback)
            
            val remoteName = info.endpointName.split("#")[0]
            endpointNames[endpointId] = remoteName
            
            activity?.runOnUiThread {
                eventSink?.success(mapOf(
                    "type" to "deviceFound",
                    "deviceId" to endpointId,
                    "deviceName" to remoteName,
                    "uniqueId" to endpointId,
                    "isRemoteDevice" to true
                ))
            }
        }

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
            if (result.status.isSuccess) {
                Log.d("NearbySyncUtility", "Connection successful with: $endpointId")
                activity?.runOnUiThread {
                    eventSink?.success(mapOf(
                        "type" to "connectionSuccess",
                        "deviceId" to endpointId,
                        "deviceName" to (endpointNames[endpointId] ?: "Unknown Device")
                    ))
                }
            } else {
                Log.e("NearbySyncUtility", "Connection failed with endpoint: $endpointId, status: ${result.status}")
                activity?.runOnUiThread {
                    eventSink?.success(mapOf(
                        "type" to "connectionFailed",
                        "deviceId" to endpointId,
                        "error" to "Connection failed: ${result.status}"
                    ))
                }
            }
        }

        override fun onDisconnected(endpointId: String) {
            Log.d("NearbySyncUtility", "Disconnected from endpoint: $endpointId")
            activity?.runOnUiThread {
                eventSink?.success(mapOf(
                    "type" to "deviceDisconnected",
                    "deviceId" to endpointId,
                    "deviceName" to (endpointNames[endpointId] ?: "Unknown Device")
                ))
            }
            // Clean up stored name
            endpointNames.remove(endpointId)
        }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            if (payload.type == Payload.Type.BYTES) {
                val message = String(payload.asBytes()!!)
                activity?.runOnUiThread {
                    eventSink?.success(mapOf(
                        "type" to "messageReceived",
                        "deviceId" to endpointId,
                        "deviceName" to (endpointNames[endpointId] ?: "Unknown Device"),
                        "message" to message
                    ))
                }
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            // Handle transfer updates if needed
        }
    }

    private fun stopAdvertising(result: Result) {
        connectionsClient.stopAdvertising()
        result.success(true)
    }

    private fun startDiscovery(result: Result) {
        if (!hasPermissions()) {
            result.error("PERMISSION_DENIED", "Required permissions not granted", null)
            return
        }

        connectionsClient.startDiscovery(
            SERVICE_ID,
            endpointDiscoveryCallback,
            discoveryOptions
        ).addOnSuccessListener {
            result.success(true)
        }.addOnFailureListener {
            result.error("DISCOVERY_FAILED", it.message, null)
        }
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            Log.d("NearbySyncUtility", "Endpoint found: $endpointId, name: ${info.endpointName}")
            
            // Check if we already have this endpoint
            if (endpointNames.containsKey(endpointId)) {
                Log.d("NearbySyncUtility", "Endpoint already known, skipping: $endpointId")
                return
            }

            activity?.runOnUiThread {
                val nameParts = info.endpointName.split("#")
                val deviceName = if (nameParts.size > 1) nameParts[0] else info.endpointName
                endpointNames[endpointId] = deviceName
                
                eventSink?.success(mapOf(
                    "type" to "deviceFound",
                    "deviceId" to endpointId,
                    "deviceName" to deviceName,
                    "uniqueId" to endpointId,
                    "isRemoteDevice" to true
                ))
            }
        }

        override fun onEndpointLost(endpointId: String) {
            Log.d("NearbySyncUtility", "Endpoint lost: $endpointId")
            activity?.runOnUiThread {
                eventSink?.success(mapOf(
                    "type" to "deviceLost",
                    "deviceId" to endpointId
                ))
            }
            endpointNames.remove(endpointId)
        }
    }

    private fun stopDiscovery(result: Result) {
        connectionsClient.stopDiscovery()
        result.success(true)
    }

    private fun connectToDevice(deviceId: String, result: Result) {
        try {
            // Check if we're already trying to connect
            if (pendingConnections.contains(deviceId)) {
                Log.d("NearbySyncUtility", "Already attempting to connect to: $deviceId")
                result.error("ALREADY_CONNECTING", "Already attempting to connect to this device", null)
                return
            }

            pendingConnections.add(deviceId)
            val deviceName = getDeviceName()

            // Stop discovery before attempting connection
            connectionsClient.stopDiscovery()
            
            // Add a small delay before requesting connection
            Handler(Looper.getMainLooper()).postDelayed({
                connectionsClient.requestConnection(
                    deviceName,
                    deviceId,
                    connectionLifecycleCallback
                ).addOnSuccessListener {
                    result.success(true)
                }.addOnFailureListener { e ->
                    Log.e("NearbySyncUtility", "Connection failed: ${e.message}")
                    pendingConnections.remove(deviceId)
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        connectWithRetry(deviceId, deviceName, result)
                    } else {
                        result.error("CONNECTION_FAILED", e.message, null)
                        // Restart discovery after failed connection
                        startDiscoveryAfterDelay()
                    }
                }
            }, 500)
        } catch (e: Exception) {
            pendingConnections.remove(deviceId)
            Log.e("NearbySyncUtility", "Connection error: ${e.message}")
            result.error("CONNECTION_ERROR", e.message, null)
            startDiscoveryAfterDelay()
        }
    }

    private fun startDiscoveryAfterDelay() {
        Handler(Looper.getMainLooper()).postDelayed({
            connectionsClient.startDiscovery(
                SERVICE_ID,
                endpointDiscoveryCallback,
                discoveryOptions
            )
        }, 1000)
    }

    private fun connectWithRetry(deviceId: String, deviceName: String, result: Result) {
        Handler(Looper.getMainLooper()).postDelayed({
            connectionsClient.requestConnection(
                "$deviceName#${System.currentTimeMillis()}",
                deviceId,
                connectionLifecycleCallback
            ).addOnSuccessListener {
                pendingConnections.remove(deviceId)
                result.success(true)
            }.addOnFailureListener { e ->
                pendingConnections.remove(deviceId)
                result.error("CONNECTION_FAILED", e.message, null)
                startDiscoveryAfterDelay()
            }
        }, 500)
    }

    private fun disconnect(deviceId: String, result: Result) {
        connectionsClient.disconnectFromEndpoint(deviceId)
        result.success(true)
    }

    private fun sendMessage(deviceId: String, message: String, result: Result) {
        val payload = Payload.fromBytes(message.toByteArray())
        connectionsClient.sendPayload(deviceId, payload)
            .addOnSuccessListener {
                result.success(true)
            }
            .addOnFailureListener {
                result.error("SEND_MESSAGE_FAILED", it.message, null)
            }
    }

    private fun hasPermissions(): Boolean {
        if (activity == null) return false
        return REQUIRED_PERMISSIONS.all {
            ContextCompat.checkSelfPermission(activity!!, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestPermissions() {
        if (activity == null) return
        ActivityCompat.requestPermissions(
            activity!!,
            REQUIRED_PERMISSIONS,
            REQUEST_CODE_REQUIRED_PERMISSIONS
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        connectionsClient = Nearby.getConnectionsClient(activity!!)
        
        binding.addRequestPermissionsResultListener { requestCode, _, grantResults ->
            if (requestCode == REQUEST_CODE_REQUIRED_PERMISSIONS) {
                if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    eventSink?.success(mapOf(
                        "type" to "permissionsGranted",
                        "granted" to true
                    ))
                } else {
                    eventSink?.success(mapOf(
                        "type" to "permissionsGranted",
                        "granted" to false
                    ))
                }
                true
            } else {
                false
            }
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
        if (::connectionsClient.isInitialized) {
            connectionsClient.stopAllEndpoints()
            pendingConnections.clear()
            endpointNames.clear()
        }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    companion object {
        private const val REQUEST_CODE_REQUIRED_PERMISSIONS = 1
    }

    private val endpointNames = mutableMapOf<String, String>()
    private val pendingConnections = mutableSetOf<String>()
}
