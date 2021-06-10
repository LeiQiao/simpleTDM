//
//  WakeCommand.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/28.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa

let WakeCommandKey = "WAK"

class WakeCommand: CommCommand {
    override init(comm: Communication) {
        super.init(comm: comm)
        self.command = WakeCommandKey
    }
    override func execute() {
        log.info("execute command \(WakeCommandKey)")
        sendMessage(message: "")
    }
    
    override func handleMessage(message: String) {
        log.info("screen wake now")
        TDMUtilities.sharedInstance.wakeScreen()
        self.ackMessage(message: "")
        self.comm?.removeCommand(command: self)
    }
    
    override func handleACKMessage(message: String) {
        log.info("remote screen wake ok")
        self.comm?.removeCommand(command: self)
    }

}
