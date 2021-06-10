//
//  TDMUtilities.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/14.
//  Copyright © 2018 lei.qiao. All rights reserved.
//

import Cocoa

class TDMUtilities: NSObject {
    static let sharedInstance = TDMUtilities()
    
    func isMaster() -> Bool {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        let machine_string = String(cString: machine)
        if machine_string.range(of: "iMac") == nil {
            return true
        }
        return false
    }
    
    func isSlave() -> Bool {
        return !isMaster()
    }
    
    func isInTargetDisplayMode() -> Bool {
        //Will have multiple objects if the the MacBook is not in clamshell mode. However, when in clamshell mode `screens` should contain only contain 1 object, this object will be the iMac's screen.
        let screens = NSScreen.screens
        if screens.count == 0 {
            return false
        }
        
        var screenIDs: [CGDirectDisplayID] = []
        for screen in screens {
            if let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                screenIDs.append(screenID)
            }
        }
        if screenIDs.count == 0 {
            return false
        }
        
        var localizedScreenNames: [String] = []
        for screenID in screenIDs {
            if let localizedScreenName = getScreenName(screenID) {
                if localizedScreenName.count > 0 {
                    localizedScreenNames.append(localizedScreenName)
                }
            }
        }

        if (localizedScreenNames.count == 0) {
            return false
        }
        
        for localizedScreenName in localizedScreenNames {
            if localizedScreenName == "iMac" {
                return true
            }
        }
        
        return false
    }
    
    func darkScreen() {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["displaysleepnow"]
        
        let out = Pipe()
        task.standardOutput = out
        
        task.launch()
    }
    
    func wakeScreen() {
        let task = Process()
        task.launchPath = "/usr/bin/caffeinate"
        task.arguments = ["-u", "-t", "1"]
        
        let out = Pipe()
        task.standardOutput = out
        
        task.launch()
    }
}
