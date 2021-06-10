//
//  PreferenceUtilities.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/21.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa
import ServiceManagement

class PreferenceUtilities: NSObject {
    static let sharedInstance = PreferenceUtilities()
    
    var port: UInt16 {
        get {
            let _port = UInt16(UserDefaults.standard.integer(forKey: "communication_port"))
            if _port <= 0 {
                return 9096
            }
            return _port
        }
        set(newPort) {
            UserDefaults.standard.set(newPort, forKey: "communication_port")
        }
    }
    
    var secretKey: String {
        get {
            guard let _secretKey = UserDefaults.standard.string(forKey: "communication_secret_key") else {
                let _secretKey = UUID().uuidString
                UserDefaults.standard.set(_secretKey, forKey: "communication_secret_key")
                return _secretKey
            }
            return _secretKey
        }
    }
    
    var rememberLastKeyboard: Bool {
        get {
            let _value = UserDefaults.standard.string(forKey: "remember_last_keyboard")
            if _value == nil {
                return true
            }
            return (_value == "1")
        }
        set (newValue) {
            UserDefaults.standard.set(newValue ? "1" : "0", forKey: "remember_last_keyboard")
        }
    }
    
    var lastKeyboard: String? {
        get {
            if !self.rememberLastKeyboard {
                return nil
            }
            
            let _value = UserDefaults.standard.string(forKey: "last_keyboard")
            return _value
        }
        set (newValue) {
            UserDefaults.standard.set(newValue, forKey: "last_keyboard")
        }
    }
    
    var lastConnectKeyboard: String?
    
    var connectKeyboardAfterEnterTDM: Bool {
        get {
            guard let _value = UserDefaults.standard.string(forKey: "connect_keyboard_after_enter_tdm") else {
                return true
            }
            return (_value == "1")
        }
        set (newValue) {
            UserDefaults.standard.set(newValue ? "1" : "0", forKey: "connect_keyboard_after_enter_tdm")
        }
    }
    
    var releaseKeyboardAfterLeaveTDM: Bool {
        get {
            let _value = UserDefaults.standard.bool(forKey: "release_keyboard_after_leave_tdm")
            return _value
        }
        set (newValue) {
            UserDefaults.standard.set(newValue ? "1" : "0", forKey: "release_keyboard_after_leave_tdm")
        }
    }
    
    var darkScreenAfterLeaveTDM: Bool {
        get {
            let _value = UserDefaults.standard.bool(forKey: "dark_screen_after_leave_tdm")
            return _value
        }
        set (newValue) {
            UserDefaults.standard.set(newValue ? "1" : "0", forKey: "dark_screen_after_leave_tdm")
        }
    }
    
    var runAtLogin: Bool {
        get {
            let _value = UserDefaults.standard.bool(forKey: "run_at_login")
            return _value
        }
        set (newValue) {
            let launcherAppIdentifier = "com.LoveC.simpleTDM.LaunchHelper"
            if SMLoginItemSetEnabled(launcherAppIdentifier as CFString, newValue) {
                UserDefaults.standard.set(newValue, forKey: "run_at_login")
            }
        }
    }
    
    var runAtLoginScreen: Bool {
        get {
            let _value = FileManager.default.fileExists(atPath: "/Library/LaunchAgents/com.LoveC.simpleTDM.plist")
            return _value
        }
        set (newValue) {
            if !newValue {
                let uninstallScript = Bundle.main.path(forResource: "uninstall_launch_agent", ofType: "sh")
                let script = String("do shell script \"bash \(uninstallScript!)\" with administrator privileges")
                let scriptRunner = NSAppleScript(source: script)
                scriptRunner?.executeAndReturnError(nil)
                return
            }
            
            let plistPath = Bundle.main.path(forResource: "launch_agent", ofType: "plist")
            var plistString: String = ""
            do {
                plistString = try String(contentsOfFile: plistPath!, encoding: String.Encoding.utf8)
            } catch let error as NSError {
                print("unable get launchAgent file \(error)")
                plistString = ""
            }
            
            if !FileManager.default.fileExists(atPath: "/tmp/com.LoveC.simpleTDM.plist") {
                if !FileManager.default.createFile(atPath: "/tmp/com.LoveC.simpleTDM.plist", contents: nil, attributes: nil) {
                    print("unable create temp file")
                }
            }
            
            guard let file = FileHandle(forWritingAtPath: "/tmp/com.LoveC.simpleTDM.plist") else {
                print("unable add launchAgent file")
                return
            }
            
            plistString = plistString.replacingOccurrences(of: "{{program_path}}", with: Bundle.main.executablePath!)
            plistString = plistString.replacingOccurrences(of: "{{port}}", with: String(PreferenceUtilities.sharedInstance.port))
            
            file.write(plistString.data(using: String.Encoding.utf8)!)
            file.closeFile()
            
            let installScript = Bundle.main.path(forResource: "install_launch_agent", ofType: "sh")
            let script = String("do shell script \"bash \(installScript ?? "")\" with administrator privileges")
            let scriptRunner = NSAppleScript(source: script)
            scriptRunner?.executeAndReturnError(nil)
        }
    }
}
