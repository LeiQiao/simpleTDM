//
//  EnterTDMComboCommand.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/26.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa

protocol EnterTDMComboCommandDelegate: EnterTDMCommandDelegate {
    func remoteKeyboardNotFound()
}

class EnterTDMComboCommand: CommCommand, QueryKeyboardCommandDelegate, ConnectKeyboardCommandDelegate, EnterTDMCommandDelegate, ReleaseKeyboardCommandDelegate, ChooseKeyboardDelegate {
    var delegate: EnterTDMComboCommandDelegate?
    var keyboardAddress: String?
    var remoteKeyboards: [[String: String]] = []
    var chooseKeyboardWindow: ChooseKeyboardWindowController?
    
    init(comm: Communication, delegate: EnterTDMComboCommandDelegate) {
        self.delegate = delegate
        super.init(comm: comm)
    }

    func execute(keyboardAddress: String?) {
        log.info("execute combo TDM command")
        self.keyboardAddress = keyboardAddress
        self.comm?.appendCommand(command: self)
        
        WakeCommand(comm: self.comm!).execute()
        QueryKeyboardCommand(comm: self.comm!, delegate: self).execute()
    }
    
    func showSelectKeyboard() {
        let localKeyboards = BlueKeyboardUtilities.sharedInstance.getAllKeyboard()
        var connectedLocalKeyboards: [BlueKeyboard] = []
        for keyboard in localKeyboards {
            if keyboard.isConnected() {
                connectedLocalKeyboards.append(keyboard)
            }
        }
        
        log.info("open choose keyboard window")
        self.chooseKeyboardWindow?.close()
        self.chooseKeyboardWindow = ChooseKeyboardWindowController(windowNibName: "ChooseKeyboardWindow")
        self.chooseKeyboardWindow?.delegate = self
        self.chooseKeyboardWindow?.setKeyboards(local: connectedLocalKeyboards, remote: self.remoteKeyboards)
        self.chooseKeyboardWindow?.window?.makeKeyAndOrderFront(nil)
        self.chooseKeyboardWindow?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func selectedKeyboard(name: String?, address: String?, object: BlueKeyboard?) {
        if address == nil {
            log.info("cancel choose keyboard")
            self.delegate?.remoteEnterTDM(success: false, reason: "no magic keyboard selected")
            self.comm?.removeCommand(command: self)
            return
        }
        
        self.keyboardAddress = address
        PreferenceUtilities.sharedInstance.lastKeyboard = address
        
        log.info("manually choose keyboard \(name ?? "") \(address ?? "**error**")")
        
        self.remoteQueryKeyboards(keyboards: self.remoteKeyboards)
    }
    
    func remoteQueryKeyboards(keyboards: [[String: String]]) {
        log.info("query remote keyboards \(keyboards)")
        
        self.remoteKeyboards = keyboards
        
        var loadFromLastKeyboard = false
        if self.keyboardAddress == nil {
            let lastKeyboard = PreferenceUtilities.sharedInstance.lastKeyboard
            log.info("load from last keyboard \(lastKeyboard ?? "**error**")")
            self.keyboardAddress = lastKeyboard
            loadFromLastKeyboard = true
        }
        
        if self.keyboardAddress == nil {
            log.info("no default keyboard, manually choose keyboard")
            self.showSelectKeyboard()
            return
        }
        
        var keyboard: BlueKeyboard? = nil
        let allKeyboards = BlueKeyboardUtilities.sharedInstance.getAllKeyboard()
        for kb in allKeyboards {
            if kb.getAddress() == keyboardAddress && kb.isConnected() {
                keyboard = kb
                break
            }
        }
        
        if keyboard != nil {
            log.info("select local keyboard, disconnect it first")
            _ = BlueKeyboardUtilities.sharedInstance.disconnect(keyboard: keyboard!)
            ConnectKeyboardCommand(comm: self.comm!, delegate: self).execute(keyboardAddress: keyboard!.getAddress())
        } else {
            var foundInRemote = false
            for kb in self.remoteKeyboards {
                if kb["address"] == self.keyboardAddress {
                    foundInRemote = true
                    break
                }
            }
            if foundInRemote {
                log.info("select remote keyboard, directly enter TDM")
                EnterTDMCommand(comm: self.comm!, delegate: self).execute()
            } else if loadFromLastKeyboard {
                log.info("unable found default keyboard in both ends, manually choose keyboard")
                self.keyboardAddress = nil
                self.showSelectKeyboard()
            } else {
                log.error("unable found select keyboard in both ends")
                self.delegate?.remoteKeyboardNotFound()
                self.comm?.removeCommand(command: self)
            }
        }
    }
    
    func remoteConnectKeyboard(success: Bool, reason: String) {
        log.error("remoteConnectKeyboard: \(success) \(reason)")
        if !success {
            self.delegate?.remoteEnterTDM(success: false, reason: reason)
            self.comm?.removeCommand(command: self)
            return
        }
        EnterTDMCommand(comm: self.comm!, delegate: self).execute()
    }
    
    func remoteEnterTDM(success: Bool, reason: String) {
        log.error("remoteEnterTDM: \(success) \(reason)")
        if !success {
            self.delegate?.remoteEnterTDM(success: false, reason: reason)
            self.comm?.removeCommand(command: self)
            return
        }
        
        if PreferenceUtilities.sharedInstance.connectKeyboardAfterEnterTDM {
            log.info("take keyboard back after enter TDM")
            ReleaseKeyboardCommand(comm: self.comm!, delegate: self).execute(keyboardAddress: self.keyboardAddress!)
        } else {
            self.remoteReleaseKeyboard(success: success, reason: reason)
        }
    }
    
    func remoteReleaseKeyboard(success: Bool, reason: String) {
        log.error("remoteReleaseKeyboard: \(success) \(reason)")
        if success {
            PreferenceUtilities.sharedInstance.lastConnectKeyboard = self.keyboardAddress
        }
        self.delegate?.remoteEnterTDM(success: success, reason: reason)
        self.comm?.removeCommand(command: self)
    }
}
