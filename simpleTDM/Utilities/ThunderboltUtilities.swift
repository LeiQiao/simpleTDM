//
//  ThunderboltUtilities.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/14.
//  Copyright © 2018 lei.qiao. All rights reserved.
//

import Cocoa
import SystemConfiguration
import Foundation

@objc protocol ThunderboltStatusDelegate {
    func thunderboltStatusChanged()
}

class ThunderboltUtilities: NSObject, NetworkInterfaceNotifierDelegate {
    var networkInterfaceNotifier: NetworkInterfaceNotifier
    var systemProfilerInformation: [Any]?
    var macConnected: Bool?
    var delegate: ThunderboltStatusDelegate?
    
    init(delegate: ThunderboltStatusDelegate) {
        self.networkInterfaceNotifier = NetworkInterfaceNotifier()
        self.delegate = delegate
        super.init()
        
        self.networkInterfaceNotifier.delegate = self;
        self.networkInterfaceNotifier.startObserving()
        
        _ = self.checkForThunderboltConnection()
    }
    
    func networkInterfaceNotifierDidDetectChanage() {
        _ = self.checkForThunderboltConnection()
    }
    
    open func checkForThunderboltConnection() -> Bool {
        print("Checking for thuderbolt connection. \n" +
              "Display Info: \(self.systemProfilerDisplayInfo()) \n" +
              "Thunderbolt Info: \(self.systemProfilerThunderboltInfo())\n" +
              "Power Assertion Info: \(self.systemAssertionInfomation())")
        self.updateSystemProfilerInformation()
        
        let previouslyConnected = self.macConnected
        
        if self.isThunderboltEnabled() {
            self.macConnected = self.macConnectedViaThunderbolt()
        } else {
            self.macConnected = self.macConnectedViaDisplayPort()
        }
        let changed = previouslyConnected != nil && previouslyConnected != self.macConnected
        
        if changed {
            self.delegate?.thunderboltStatusChanged()
        }
        
        return changed
    }
    
    func updateSystemProfilerInformation() {
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPDisplaysDataType", "SPThunderboltDataType", "-xml"]
        
        let out = Pipe()
        task.standardOutput = out
        
        task.launch()
        
        let dataRead = out.fileHandleForReading.readDataToEndOfFile()
        let plist = try! PropertyListSerialization.propertyList(from: dataRead,
                                                                options: [],
                                                                format: nil) as! [Any]
        self.systemProfilerInformation =  plist
    }
    
    func systemProfilerDisplayInfo() -> [String: Any] {
        if (self.systemProfilerInformation == nil) {
            self.updateSystemProfilerInformation()
        }
        
        return self.systemProfilerInformation?[0] as! [String: Any]
    }
    
    func systemProfilerThunderboltInfo() -> [String: Any] {
        if self.systemProfilerInformation == nil {
            self.updateSystemProfilerInformation()
        }
        
        return self.systemProfilerInformation?[1] as! [String: Any]
    }
    
    func systemAssertionInfomation() -> String {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g", "assertions"]
    
        let out = Pipe()
        task.standardOutput = out
        
        task.launch()
    
        let dataRead = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: dataRead, encoding: String.Encoding.utf8)!
    }
    
    func isThunderboltEnabled() -> Bool {
        let profilerResponse = self.systemProfilerThunderboltInfo()
        
        if profilerResponse.count >= 1 {
            let items = profilerResponse["_items"] as! [Any]
            
            if items.count == 0 {
                return false
            }
            let busName = (items[0] as! [String: Any])["_name"] as! String
            
            if busName == "thunderbolt_bus" {
                return true
            }
            return false
        }
        
        return false
    }
    
    func macConnectedViaDisplayPort() -> Bool {
        let assertionString = self.systemAssertionInfomation()
        //The Display Port daemon. If this isn't holding an assertion then the iMac isn't in TDM.
        if assertionString.contains("com.apple.dpd") {
            return true
        }
        
        let plist = self.systemProfilerDisplayInfo()
        
        let gpus = plist["_items"] as! [Any]
        
        for gpu in gpus {
            let displays = (gpu as! [String: Any])["spdisplays_ndrvs"] as! [[String: String]]
            
            for display in displays {
                if display["spdisplays_connection_type"] == "spdisplays_displayport_dongletype_dp" {
                    if display["_spdisplays_display-vendor-id"] == "610" {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    func macConnectedViaThunderbolt() -> Bool {
        let plist = self.systemProfilerThunderboltInfo()
        let items = (plist["_items"] as! [Any])[0] as! [String: Any]
        guard let devices = items["_items"] else {
            return false
        }
    
        for device in devices as! [Any] {
            let vendor_id_key = (device as! [String: Any])["vendor_id_key"]
            if (vendor_id_key as! String) == "0xA27" {
                return true
            }
        }
    
        return false
    }
}


@objc protocol NetworkInterfaceNotifierDelegate {
    func networkInterfaceNotifierDidDetectChanage()
}

class NetworkInterfaceNotifier: NSObject {
    
    struct NetworkInterface {
        let BSDName: String
        let displayName: String
    }
    
    var delegate: NetworkInterfaceNotifierDelegate?
    
    func startObserving() {
        
        func callback(store: SCDynamicStore, changedKeys: CFArray, context: UnsafeMutableRawPointer?) -> Void {
            guard context != nil else { return }
            
            let mySelf = Unmanaged<NetworkInterfaceNotifier>.fromOpaque(context!).takeUnretainedValue()
            mySelf.delegate?.networkInterfaceNotifierDidDetectChanage()
        }
        
        OperationQueue().addOperation {
            
            guard Bundle.main.bundleIdentifier != nil else {
                print("Could not get bundle identifier")
                return
            }
            
            var context = SCDynamicStoreContext(version: 0, info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), retain: nil, release: nil, copyDescription: nil)
            
            guard let store = SCDynamicStoreCreate(nil, Bundle.main.bundleIdentifier! as CFString, callback, &context) else {
                print("Could not connect SCDynamicStoreCreate")
                return
            }
            
            var interfaces:[NetworkInterface] = []
            
            for interface in SCNetworkInterfaceCopyAll() as NSArray {
                if let name = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
                    let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface) {
                    interfaces.append(NetworkInterface(BSDName: name as String, displayName: displayName as String))
                    print("Hardware Port: \(displayName) \nInterface \(name)")
                }
            }
            
            var keys = [CFString]()
            
            for interface in interfaces {
                if interface.displayName.contains("Thunderbolt") && interface.displayName.contains("Bridge") == false {
                    keys.append("State:/Network/Interface/\(interface.BSDName)/LinkQuality" as CFString)
                }
            }
            
            SCDynamicStoreSetNotificationKeys(store, keys as CFArray, nil)
            
            let runloop = SCDynamicStoreCreateRunLoopSource(nil, store, 0)
            CFRunLoopAddSource(RunLoop.current.getCFRunLoop(), runloop, CFRunLoopMode.commonModes)
            RunLoop.current.run()
        }
    }
}
