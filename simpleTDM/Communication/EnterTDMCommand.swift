//
//  EnterTDMCommand.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/22.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa

let EnterTDMCommandKey = "TDM"

protocol EnterTDMCommandDelegate {
    func remoteEnterTDM(success: Bool, reason: String)
}

class EnterTDMCommand: CommCommand {
    var delegate: EnterTDMCommandDelegate?
    var detectTimer: Timer?
    var detectTimes: Int = 20
    
    init(comm: Communication, delegate: EnterTDMCommandDelegate?) {
        super.init(comm: comm)
        self.delegate = delegate
        self.command = EnterTDMCommandKey
    }
    
    override func execute() {
        log.info("execute command \(EnterTDMCommandKey)")
        
        self.comm?.appendCommand(command: self)
        
        self.detectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { (timer: Timer) in
            if TDMUtilities.sharedInstance.isInTargetDisplayMode() {
                log.info("enter TDM ok, notice remote")
                self.sendMessage(message: "ok")
            } else {
                log.info("ask remote to enter TDM")
                self.sendMessage(message: "")
            }
            
            self.detectTimes -= 1
            if self.detectTimes <= 0 {
                log.error("unable enter TDM, timeout")
                
                self.detectTimer?.invalidate()
                self.detectTimer = nil
                let success = TDMUtilities.sharedInstance.isInTargetDisplayMode()
                var reason = "timeout"
                if success {
                    reason = ""
                }
                self.delegate?.remoteEnterTDM(success: success, reason: reason)
                self.comm?.removeCommand(command: self)
            }
        })
    }
    
    override func handleMessage(message: String) {
        if message != "ok" {
            log.info("remote ask me to enter TDM")
            let app = NSApplication.shared.delegate as! AppDelegate
            if app.silenceMode {
                log.info("I am in login screen please manually enter TDM")
                self.ackMessage(message: "login_screen_session")
                self.comm?.removeCommand(command: self)
            } else {
                log.info("simulate press Command + F2")
                enterTargetDisplayMode()
            }
        } else {
            log.info("enter TDM ok")
            self.ackMessage(message: "ok")
            self.comm?.removeCommand(command: self)
        }
    }
    
    override func handleACKMessage(message: String) {
        self.detectTimer?.invalidate()
        self.detectTimer = nil
        
        if message == "login_screen_session" {
            log.info("remote in login screen please manually enter TDM")
            self.delegate?.remoteEnterTDM(success: false, reason: "remote is in login screen please login first or manually enter TDM by press \n\"Command + F2\"\n(keyboard has been already connected to remote)")
        } else {
            log.info("success enter TDM")
            self.delegate?.remoteEnterTDM(success: true, reason: "")
        }
        self.comm?.removeCommand(command: self)
    }
}
