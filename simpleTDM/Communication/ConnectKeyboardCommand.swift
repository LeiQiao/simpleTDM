//
//  ConnectKeyboardCommand.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/22.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa

let ConnectKeyboardCommandKey = "CKB"

protocol ConnectKeyboardCommandDelegate {
    func remoteConnectKeyboard(success: Bool, reason: String)
}

class ConnectKeyboardCommand: CommCommand, ChooseKeyboardDelegate {
    var delegate: ConnectKeyboardCommandDelegate?
    var chooseKeyboardWindow: ChooseKeyboardWindowController?
    var keyboardAddress: String?
    var connectingKeyboard: BlueKeyboard?
    var detectTimer: Timer?
    var detectTimes: Int = 20
    
    init(comm: Communication, delegate: ConnectKeyboardCommandDelegate?) {
        super.init(comm: comm)
        self.delegate = delegate
        self.command = ConnectKeyboardCommandKey
    }
    
    func execute(keyboardAddress: String?) {
        log.info("execute command \(ConnectKeyboardCommandKey)")
        
        self.comm?.appendCommand(command: self)
        
        self.keyboardAddress = keyboardAddress
        if keyboardAddress == nil {
            log.info("select local keyboard to connect")
            var allConnectedKeyboards: [BlueKeyboard] = []
            for keyboard in BlueKeyboardUtilities.sharedInstance.getAllKeyboard() {
                if keyboard.isConnected() {
                    allConnectedKeyboards.append(keyboard)
                }
            }
            
            if allConnectedKeyboards.count <= 0 {
                log.info("no keyboard connected locally")
                self.delegate?.remoteConnectKeyboard(success: false, reason: "no keyboard connected")
                self.comm?.removeCommand(command: self)
                return
            }
            
            log.info("pop choose keyboard window")
            self.chooseKeyboardWindow?.close()
            self.chooseKeyboardWindow = ChooseKeyboardWindowController(windowNibName: "ChooseKeyboardWindow")
            self.chooseKeyboardWindow?.delegate = self
            self.chooseKeyboardWindow?.setKeyboards(local: allConnectedKeyboards, remote: [])
            self.chooseKeyboardWindow?.window?.makeKeyAndOrderFront(nil)
            self.chooseKeyboardWindow?.window?.center()
            NSApp.activate(ignoringOtherApps: true)
            return
        } else {
            log.info("disconnect keyboard \(keyboardAddress ?? "**error**") first")
            for keyboard in BlueKeyboardUtilities.sharedInstance.getAllKeyboard() {
                if keyboard.getAddress() == keyboardAddress && keyboard.isConnected() {
                    _ = BlueKeyboardUtilities.sharedInstance.disconnect(keyboard: keyboard)
                    break
                }
            }
        }
        self.sendMessage(message: self.keyboardAddress!)
    }
    
    func selectedKeyboard(name: String?, address: String?, object: BlueKeyboard?) {
        if address == nil {
            log.info("cancel choose keyboard")
            self.delegate?.remoteConnectKeyboard(success: false, reason: "user canceled")
            self.comm?.removeCommand(command: self)
            return
        }
        
        log.info("manually choose keyboard \(name ?? "") \(address ?? "**error**")")
        
        self.keyboardAddress = address
        if object != nil {
            log.info("disconnect keyboard \(address ?? "**error**") first")
            _ = BlueKeyboardUtilities.sharedInstance.disconnect(keyboard: object!)
        }
        self.sendMessage(message: self.keyboardAddress!)
    }
    
    override func handleMessage(message: String) {
        let allKeyboards = BlueKeyboardUtilities.sharedInstance.getAllKeyboard()
        for keyboard in allKeyboards {
            if keyboard.getAddress() == message {
                log.info("connect keyboard \(keyboard.getName() ?? "**error**") \(keyboard.getAddress() ?? "**error**")")
                self.connectKeyboard(keyboard: keyboard)
                return
            }
        }
        log.error("keyboard \(message) not paird")
        self.connectKeyboard(keyboard: nil)
    }
    
    func connectKeyboard(keyboard: BlueKeyboard?) {
        if keyboard == nil {
            self.ackResult(success: false, reason: "keyboard not paird")
            return
        }
        
        log.info("start connecting keyboard: \(keyboard?.getName() ?? "**error**") \(keyboard?.getAddress() ?? "**error**")")
        
        self.connectingKeyboard = keyboard
        _ = BlueKeyboardUtilities.sharedInstance.connect(keyboard: self.connectingKeyboard!)
        
        self.detectTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (timer: Timer) in
            if (self.connectingKeyboard?.isConnected())! {
                log.info("keyboard connected \(keyboard?.getName() ?? "**error**") \(keyboard?.getAddress() ?? "**error**")")
                
                self.detectTimer?.invalidate()
                self.detectTimer = nil
                self.ackResult(success: true, reason: "")
                return
            }
            
            log.warning("keyboard not connected yet \(keyboard?.getName() ?? "**error**") \(keyboard?.getAddress() ?? "**error**") retry")
            
            _ = BlueKeyboardUtilities.sharedInstance.connect(keyboard: self.connectingKeyboard!)
            self.detectTimes -= 1
            if self.detectTimes <= 0 {
                log.error("unable connect keyboard \(keyboard?.getName() ?? "**error**") \(keyboard?.getAddress() ?? "**error**") timeout")
                self.ackResult(success: false, reason: "connect timeout")
            }
        })
    }
    
    func ackResult(success: Bool, reason: String) {
        self.detectTimer?.invalidate()
        self.detectTimer = nil
        
        let result: [String: Any] = [
            "success": success,
            "reason": reason
        ]
        self.ackMessage(message: result)
        self.comm?.removeCommand(command: self)
    }
    
    override func handleACKMessage(message: String) {
        let message:[String: Any] = self.comm?.unwarpJSON(jsonString: message) as! [String : Any]
        let success = (message["success"] ?? false) as! Bool
        let reason = (message["reason"] ?? "") as! String
        
        log.info("remote connect keyboard \(success) \(reason)")
        
        self.delegate?.remoteConnectKeyboard(success: success, reason: reason)
        self.comm?.removeCommand(command: self)
    }
}
