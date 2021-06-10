//
//  ReleaseKeyboardCommand.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/22.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa

let ReleaseKeyboardCommandKey = "RKB"

protocol ReleaseKeyboardCommandDelegate {
    func remoteReleaseKeyboard(success: Bool, reason: String)
}

class ReleaseKeyboardCommand: CommCommand, QueryKeyboardCommandDelegate, ChooseKeyboardDelegate {
    var delegate: ReleaseKeyboardCommandDelegate?
    var chooseKeyboardWindow: ChooseKeyboardWindowController?
    var keyboardAddress: String?
    var disconnectingKeyboard: BlueKeyboard?
    var detectTimer: Timer?
    var detectTimes: Int = 20
    var connectDetectTimes: Int = 6
    
    init(comm: Communication, delegate: ReleaseKeyboardCommandDelegate?) {
        super.init(comm: comm)
        self.delegate = delegate
        self.command = ReleaseKeyboardCommandKey
    }
    
    func execute(keyboardAddress: String?) {
        log.info("execute command \(ReleaseKeyboardCommandKey)")
        
        self.comm?.appendCommand(command: self)
        self.keyboardAddress = keyboardAddress
        
        if keyboardAddress == nil {
            log.info("select remote keyboard to disconnect")
            QueryKeyboardCommand(comm: self.comm!, delegate: self).execute()
            return
        }
        self.sendMessage(message: self.keyboardAddress!)
    }
    
    func remoteQueryKeyboards(keyboards: [[String : String]]) {
        if keyboards.count <= 0 {
            log.error("no keyboard connected in remote")
            self.delegate?.remoteReleaseKeyboard(success: false, reason: "no keyboard connected in remote")
            self.comm?.removeCommand(command: self)
            return
        }
        
        log.info("open choose keyboard window")
        self.chooseKeyboardWindow?.close()
        self.chooseKeyboardWindow = ChooseKeyboardWindowController(windowNibName: "ChooseKeyboardWindow")
        self.chooseKeyboardWindow?.delegate = self
        self.chooseKeyboardWindow?.setKeyboards(local: [], remote: keyboards)
        self.chooseKeyboardWindow?.window?.makeKeyAndOrderFront(nil)
        self.chooseKeyboardWindow?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func selectedKeyboard(name: String?, address: String?, object: BlueKeyboard?) {
        if address == nil {
            log.info("cancel choose keyboard")
            self.delegate?.remoteReleaseKeyboard(success: false, reason: "user canceled")
            self.comm?.removeCommand(command: self)
            return
        }
        
        log.info("manually choose keyboard \(name ?? "") \(address ?? "**error**")")
        
        self.keyboardAddress = address
        self.sendMessage(message: self.keyboardAddress!)
    }
    
    override func handleMessage(message: String) {
        let allKeyboards = BlueKeyboardUtilities.sharedInstance.getAllKeyboard()
        for keyboard in allKeyboards {
            if keyboard.getAddress() == message {
                log.info("disconnect keyboard \(keyboard.getName() ?? "**error**") \(keyboard.getAddress() ?? "**error**")")
                self.disconnectKeyboard(keyboard: keyboard)
                return
            }
        }
        log.error("keyboard \(message) not paird")
        self.disconnectKeyboard(keyboard: nil)
    }
    
    func disconnectKeyboard(keyboard: BlueKeyboard?) {
        if keyboard == nil {
            self.ackResult(success: false, reason: "keyboard not paird")
            return
        }
        
        log.info("start disconnecting keyboard: \(keyboard?.getName() ?? "**error**") \(keyboard?.getAddress() ?? "**error**")")
        self.disconnectingKeyboard = keyboard
        _ = BlueKeyboardUtilities.sharedInstance.disconnect(keyboard: self.disconnectingKeyboard!)
        
        self.detectTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (timer: Timer) in
            if !((keyboard?.isConnected())!) {
                log.info("keyboard disconnected \(keyboard?.getName() ?? "**error**") \(keyboard?.getAddress() ?? "**error**")")
                self.detectTimer?.invalidate()
                self.detectTimer = nil
                self.ackResult(success: true, reason: "")
                return
            }
            
            log.warning("keyboard not disconnected yet \(keyboard?.getName() ?? "**error**") \(keyboard?.getAddress() ?? "**error**") retry")
            
            _ = BlueKeyboardUtilities.sharedInstance.disconnect(keyboard: self.disconnectingKeyboard!)
            self.detectTimes -= 1
            if self.detectTimes <= 0 {
                log.error("unable disconnect keyboard \(keyboard?.getName() ?? "**error**") \(keyboard?.getAddress() ?? "**error**") timeout")
                self.ackResult(success: false, reason: "disconnect timeout")
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
        
        if !success {
            self.delegate?.remoteReleaseKeyboard(success: success, reason: reason)
            self.comm?.removeCommand(command: self)
            return
        }
        
        log.info("start connecting keyboard: \(self.keyboardAddress ?? "**error**")")
        
        self.detectTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true, block: { (timer: Timer) in
            let allKeyboards = BlueKeyboardUtilities.sharedInstance.getAllKeyboard()
            var connectKeyboard: BlueKeyboard? = nil
            for keyboard in allKeyboards {
                if keyboard.getAddress() == self.keyboardAddress {
                    connectKeyboard = keyboard
                    break
                }
            }
            if connectKeyboard == nil {
                log.error("remote keyboard \(self.keyboardAddress!) did disconnected, but keyboard not pair with this computer")
                
                self.detectTimer?.invalidate()
                self.detectTimer = nil
                self.delegate?.remoteReleaseKeyboard(success: false, reason: "remote keyboard did disconnected, but keyboard not pair with this computer")
                self.comm?.removeCommand(command: self)
                return
            }
            
            if (connectKeyboard?.isConnected())! {
                log.info("keyboard connected \(connectKeyboard?.getName() ?? "**error**") \(connectKeyboard?.getAddress() ?? "**error**")")
                
                self.detectTimer?.invalidate()
                self.detectTimer = nil
                self.delegate?.remoteReleaseKeyboard(success: true, reason: "")
                self.comm?.removeCommand(command: self)
                return
            }
            
            log.warning("keyboard not connected yet \(connectKeyboard?.getName() ?? "**error**") \(connectKeyboard?.getAddress() ?? "**error**") retry")
            
            self.connectDetectTimes -= 1
            _ = BlueKeyboardUtilities.sharedInstance.connect(keyboard: connectKeyboard!)
            
            if self.connectDetectTimes <= 0 {
                log.error("unable connect keyboard \(connectKeyboard?.getName() ?? "**error**") \(connectKeyboard?.getAddress() ?? "**error**") timeout")
                
                self.detectTimer?.invalidate()
                self.detectTimer = nil
                self.delegate?.remoteReleaseKeyboard(success: false, reason: "remote keyboard did disconnected, but keyboard unable connect to this computer, please manually connect it.")
                self.comm?.removeCommand(command: self)
                return
            }
        })
    }
}
