//
//  SettingWindow.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/26.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa

protocol SettingDelegate {
    func portDidChanged()
}

class SettingWindowController: NSWindowController, NSTextFieldDelegate {
    @IBOutlet var portInput: NSTextField!
    @IBOutlet var rememberLastKeyboard: NSButton!
    @IBOutlet var connectKeyboardAfterEnterTDM: NSButton!
    @IBOutlet var releaseKeyboardAfterLeaveTDM: NSButton!
    @IBOutlet var darkScreenAfterLeaveTDM: NSButton!
    @IBOutlet var runAtLogin: NSButton!
    @IBOutlet var runAtLoginScreen: NSButton!
    var delegate: SettingDelegate?

    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.portInput.stringValue = String(PreferenceUtilities.sharedInstance.port)
        if PreferenceUtilities.sharedInstance.rememberLastKeyboard {
            self.rememberLastKeyboard.state = NSControl.StateValue.on
        } else {
            self.rememberLastKeyboard.state = NSControl.StateValue.off
        }
        if PreferenceUtilities.sharedInstance.connectKeyboardAfterEnterTDM {
            self.connectKeyboardAfterEnterTDM.state = NSControl.StateValue.on
        } else {
            self.connectKeyboardAfterEnterTDM.state = NSControl.StateValue.off
        }
        if PreferenceUtilities.sharedInstance.releaseKeyboardAfterLeaveTDM {
            self.releaseKeyboardAfterLeaveTDM.state = NSControl.StateValue.on
        } else {
            self.releaseKeyboardAfterLeaveTDM.state = NSControl.StateValue.off
        }
        if PreferenceUtilities.sharedInstance.runAtLogin {
            self.runAtLogin.state = NSControl.StateValue.on
        } else {
            self.runAtLogin.state = NSControl.StateValue.off
        }
        if PreferenceUtilities.sharedInstance.runAtLoginScreen {
            self.runAtLoginScreen.state = NSControl.StateValue.on
        } else {
            self.runAtLoginScreen.state = NSControl.StateValue.off
        }
        
        if TDMUtilities.sharedInstance.isSlave() {
            self.rememberLastKeyboard.isEnabled = false
            self.connectKeyboardAfterEnterTDM.isEnabled = false
            self.releaseKeyboardAfterLeaveTDM.isEnabled = false
            self.darkScreenAfterLeaveTDM.isEnabled = false
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if !self.changePort() {
            self.portInput.becomeFirstResponder()
            return false
        }
        return true
    }
    
    
    func controlTextDidEndEditing(_ obj: Notification) {
        _ = self.changePort()
    }
    
    @IBAction func onChangeRememberLastKeyboard(sender: Any) {
        if self.rememberLastKeyboard.state == NSControl.StateValue.on {
            PreferenceUtilities.sharedInstance.rememberLastKeyboard = true
        } else {
            PreferenceUtilities.sharedInstance.rememberLastKeyboard = false
        }
    }
    
    @IBAction func onChangeConnectKeyboardAfterEnterTDM(sender: Any) {
        if self.connectKeyboardAfterEnterTDM.state == NSControl.StateValue.on {
            PreferenceUtilities.sharedInstance.connectKeyboardAfterEnterTDM = true
        } else {
            PreferenceUtilities.sharedInstance.connectKeyboardAfterEnterTDM = false
        }
    }
    
    @IBAction func onChangeReleaseKeyboardAfterLeaveTDM(sender: Any) {
        if self.releaseKeyboardAfterLeaveTDM.state == NSControl.StateValue.on {
            PreferenceUtilities.sharedInstance.releaseKeyboardAfterLeaveTDM = true
        } else {
            PreferenceUtilities.sharedInstance.releaseKeyboardAfterLeaveTDM = false
        }
    }
    
    @IBAction func darkScreenAfterLeaveTDM(sender: Any) {
        if self.darkScreenAfterLeaveTDM.state == NSControl.StateValue.on {
            PreferenceUtilities.sharedInstance.darkScreenAfterLeaveTDM = true
        } else {
            PreferenceUtilities.sharedInstance.darkScreenAfterLeaveTDM = false
        }
    }
    
    @IBAction func onChangeRunAtLogin(sender: Any) {
        if self.runAtLogin.state == NSControl.StateValue.on {
            PreferenceUtilities.sharedInstance.runAtLogin = true
        } else {
            PreferenceUtilities.sharedInstance.runAtLogin = false
        }
    }
    
    @IBAction func onChangeRunAtLoginScreen(sender: Any) {
        if self.runAtLoginScreen.state == NSControl.StateValue.on {
            PreferenceUtilities.sharedInstance.runAtLoginScreen = true
        } else {
            PreferenceUtilities.sharedInstance.runAtLoginScreen = false
        }
    }
    
    func changePort() -> Bool {
        if let port = UInt16(self.portInput.stringValue) {
            if port <= 0 {
                self.portInput.stringValue = "> 0"
                self.portInput.selectText(nil)
                return false
            } else if port > 65535 {
                self.portInput.stringValue = "< 65535"
                self.portInput.selectText(nil)
                return false
            }
            
            var portChanged = false
            if PreferenceUtilities.sharedInstance.port != port {
                portChanged = true
            }
            
            PreferenceUtilities.sharedInstance.port = port
            
            if portChanged {
                self.delegate?.portDidChanged()
                if PreferenceUtilities.sharedInstance.runAtLoginScreen {
                    PreferenceUtilities.sharedInstance.runAtLoginScreen = true
                }
            }
            return true
        } else {
            self.portInput.stringValue = "Invalid Number"
            self.portInput.selectText(nil)
            return false
        }
    }

}
