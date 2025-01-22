import Flutter
import UIKit
import MultipeerConnectivity

public class NearbySyncUtilityPlugin: NSObject, FlutterPlugin {
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var session: MCSession?
    private var peerID: MCPeerID?
    private var eventSink: FlutterEventSink?
    
    private let serviceType = "nearby-sync"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "nearby_sync_utility", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "nearby_sync_utility_events", binaryMessenger: registrar.messenger())
        
        let instance = NearbySyncUtilityPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startAdvertising":
            guard let args = call.arguments as? [String: Any],
                  let deviceName = args["deviceName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Device name is required", details: nil))
                return
            }
            startAdvertising(deviceName: deviceName, result: result)
            
        case "stopAdvertising":
            stopAdvertising(result: result)
            
        case "startDiscovery":
            startDiscovery(result: result)
            
        case "stopDiscovery":
            stopDiscovery(result: result)
            
        case "connectToDevice":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Device ID is required", details: nil))
                return
            }
            connectToDevice(deviceId: deviceId, result: result)
            
        case "disconnect":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Device ID is required", details: nil))
                return
            }
            disconnect(deviceId: deviceId, result: result)
            
        case "sendMessage":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  let message = args["message"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Device ID and message are required", details: nil))
                return
            }
            sendMessage(deviceId: deviceId, message: message, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startAdvertising(deviceName: String, result: @escaping FlutterResult) {
        peerID = MCPeerID(displayName: deviceName)
        session = MCSession(peer: peerID!, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID!, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        result(true)
    }
    
    private func stopAdvertising(result: @escaping FlutterResult) {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        result(true)
    }
    
    private func startDiscovery(result: @escaping FlutterResult) {
        if peerID == nil {
            peerID = MCPeerID(displayName: "Device-\(UUID().uuidString)")
            session = MCSession(peer: peerID!, securityIdentity: nil, encryptionPreference: .required)
            session?.delegate = self
        }
        
        browser = MCNearbyServiceBrowser(peer: peerID!, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        result(true)
    }
    
    private func stopDiscovery(result: @escaping FlutterResult) {
        browser?.stopBrowsingForPeers()
        browser = nil
        result(true)
    }
    
    private func connectToDevice(deviceId: String, result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "SESSION_ERROR", message: "No active session", details: nil))
            return
        }
        
        if let peer = session.connectedPeers.first(where: { $0.displayName == deviceId }) {
            result(true)
        } else {
            result(FlutterError(code: "PEER_NOT_FOUND", message: "Peer not found", details: nil))
        }
    }
    
    private func disconnect(deviceId: String, result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "SESSION_ERROR", message: "No active session", details: nil))
            return
        }
        
        if let peer = session.connectedPeers.first(where: { $0.displayName == deviceId }) {
            session.disconnect()
            result(true)
        } else {
            result(FlutterError(code: "PEER_NOT_FOUND", message: "Peer not found", details: nil))
        }
    }
    
    private func sendMessage(deviceId: String, message: String, result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "SESSION_ERROR", message: "No active session", details: nil))
            return
        }
        
        if let peer = session.connectedPeers.first(where: { $0.displayName == deviceId }) {
            do {
                try session.send(message.data(using: .utf8)!, toPeers: [peer], with: .reliable)
                result(true)
            } catch {
                result(FlutterError(code: "SEND_ERROR", message: error.localizedDescription, details: nil))
            }
        } else {
            result(FlutterError(code: "PEER_NOT_FOUND", message: "Peer not found", details: nil))
        }
    }
}

extension NearbySyncUtilityPlugin: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
        
        eventSink?([
            "type": "deviceFound",
            "deviceId": peerID.displayName,
            "deviceName": peerID.displayName
        ])
    }
}

extension NearbySyncUtilityPlugin: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        eventSink?([
            "type": "deviceFound",
            "deviceId": peerID.displayName,
            "deviceName": peerID.displayName
        ])
        
        browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 30)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        eventSink?([
            "type": "deviceLost",
            "deviceId": peerID.displayName
        ])
    }
}

extension NearbySyncUtilityPlugin: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            eventSink?([
                "type": "connected",
                "deviceId": peerID.displayName
            ])
        case .notConnected:
            eventSink?([
                "type": "disconnected",
                "deviceId": peerID.displayName
            ])
        default:
            break
        }
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = String(data: data, encoding: .utf8) {
            eventSink?([
                "type": "messageReceived",
                "deviceId": peerID.displayName,
                "message": message
            ])
        }
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NearbySyncUtilityPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
