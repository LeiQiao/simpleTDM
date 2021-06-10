//
//  SleepCommand.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/28.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa

let SleepCommandKey = "SLP"

class SleepCommand: CommCommand {
    override init(comm: Communication) {
        super.init(comm: comm)
        self.command = SleepCommandKey
    }
    override func execute() {
        log.info("execute command \(SleepCommandKey)")
        sendMessage(message: "")
    }
    
    override func handleMessage(message: String) {
        log.info("screen sleep now")
        TDMUtilities.sharedInstance.darkScreen()
        self.ackMessage(message: "")
        self.comm?.removeCommand(command: self)
    }
    
    override func handleACKMessage(message: String) {
        log.info("remote screen sleep ok")
        self.comm?.removeCommand(command: self)
    }
}
