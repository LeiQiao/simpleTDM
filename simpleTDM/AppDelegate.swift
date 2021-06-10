//
//  AppDelegate.swift
//  biu
//
//  Created by lei.qiao on 2018/11/20.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa
import ServiceManagement
import SwiftyBeaver

let log = SwiftyBeaver.self

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CommunicationDelegate, ThunderboltStatusDelegate, EnterTDMComboCommandDelegate, ConnectKeyboardCommandDelegate {
    var comm: Communication?
    var controller: TDMController?
    var thunder: ThunderboltUtilities?
    var silenceMode: Bool = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        for index in 0...CommandLine.arguments.count-1 {
            if CommandLine.arguments[index] == "--silence"{
                self.silenceMode = true
            }
            if CommandLine.arguments[index] == "--port" && index < CommandLine.arguments.count-1 {
                if let silencePort = UInt16(CommandLine.arguments[index+1]) {
                    PreferenceUtilities.sharedInstance.port = silencePort
                }
            }
        }
        
        let file = FileDestination()
        if !self.silenceMode {
            file.logFileURL = URL(fileURLWithPath: "/tmp/simpleTDM.log")
        }
        log.addDestination(file)
        
        if self.comm == nil {
            self.comm = Communication(delegate: self)
        } else if self.silenceMode {
            self.comm?.changePort()
        }
        
        if TDMUtilities.sharedInstance.isMaster() {
            log.info("master create thunder monitor")
            thunder = ThunderboltUtilities(delegate: self)
        }
        
        for index in 0...CommandLine.arguments.count-1 {
            if CommandLine.arguments[index] == "--silence"{
                log.info("run in silence mode")
                self.controller = nil
                return
            }
        }
        if self.silenceMode {
            log.info("run in silence mode")
        } else {
            log.info("run in UI mode")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func remoteConnected() {
        log.info("connected with \(self.comm!.remoteIP!)")
        self.controller?.updateMenuStatus()
        
        if !TDMUtilities.sharedInstance.isInTargetDisplayMode() && (self.thunder?.macConnected ?? false) {
            log.info("entering TDM when thunder plugined")
            EnterTDMComboCommand(comm: self.comm!, delegate: self).execute(keyboardAddress: nil)
        }
    }
    
    func remoteDisconnected() {
        log.info("disconnected")
        self.controller?.updateMenuStatus()
    }
    
    func remoteConflitWarning() {
        log.info("conflit")
        self.controller?.updateMenuStatus()
    }
    
    func thunderboltStatusChanged() {
        self.controller?.updateMenuStatus()
        if (self.thunder?.macConnected)! {
            log.info("thunder plugin, entering TDM...")
            EnterTDMComboCommand(comm: self.comm!, delegate: self).execute(keyboardAddress: nil)
        } else {
            log.info("thunder unplug, leaving TDM...")
            let lastKeyboardAddress = PreferenceUtilities.sharedInstance.lastConnectKeyboard
            if PreferenceUtilities.sharedInstance.releaseKeyboardAfterLeaveTDM && lastKeyboardAddress != nil {
                log.info("give keyboard \(lastKeyboardAddress!) back to slave")
                ConnectKeyboardCommand(comm: self.comm!, delegate: self).execute(keyboardAddress:lastKeyboardAddress)
            }
            if PreferenceUtilities.sharedInstance.darkScreenAfterLeaveTDM {
                log.info("drak remote screen")
                SleepCommand(comm: self.comm!).execute()
            }
        }
    }
    
    func remoteEnterTDM(success: Bool, reason: String) {
        log.info("remoteEnterTDM: \(success) \(reason)")
        if !success && self.controller != nil {
            let alert = NSAlert()
            alert.messageText = "simpleTDM"
            alert.informativeText = "unable enter TDM, \(reason)."
            alert.alertStyle = NSAlert.Style.critical
            alert.runModal()
        }
    }
    
    func remoteKeyboardNotFound() {
        log.error("remoteKeyboardNotFound")
        if self.controller != nil {
            let alert = NSAlert()
            alert.messageText = "simpleTDM"
            alert.informativeText = "unable enter TDM, keyboard not paird."
            alert.alertStyle = NSAlert.Style.critical
            alert.runModal()
        }
    }

    func remoteConnectKeyboard(success: Bool, reason: String) {
        log.info("remoteConnectKeyboard: \(success) \(reason)")
    }
}

