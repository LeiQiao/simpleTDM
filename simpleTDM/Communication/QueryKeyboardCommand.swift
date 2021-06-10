//
//  QueryKeyboardCommand.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/21.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa

let QueryKeyboardCommandKey: String = "QKB"

protocol QueryKeyboardCommandDelegate {
    func remoteQueryKeyboards(keyboards: [[String: String]])
}

class QueryKeyboardCommand: CommCommand {
    var delegate: QueryKeyboardCommandDelegate?
    
    init(comm: Communication, delegate: QueryKeyboardCommandDelegate?) {
        super.init(comm: comm)
        self.delegate = delegate
        self.command = QueryKeyboardCommandKey
    }
    
    override func execute() {
        log.info("execute command \(QueryKeyboardCommandKey)")
        
        self.comm?.appendCommand(command: self)
        self.sendMessage(message: "")
    }
    
    override func terminate() {
    }
    
    override func handleMessage(message: String) {
        log.info("handle \(QueryKeyboardCommandKey) message")
        let keyboards = BlueKeyboardUtilities.sharedInstance.getAllKeyboard()
        var keyboardDesc: [[String: String]] = []
        for keyboard in keyboards {
            if !keyboard.isConnected() {
                continue
            }
            keyboardDesc.append([
                "name": keyboard.getName(),
                "address": keyboard.getAddress()
                ])
        }
        self.ackMessage(message: keyboardDesc)
        self.comm?.removeCommand(command: self)
    }
    
    override func handleACKMessage(message: String) {
        log.info("handle \(QueryKeyboardCommandKey) message")
        log.info("remote have connected keyboards: \(message)")
        let keyboards = self.comm?.unwarpJSON(jsonString: message) as! [[String: String]]
        self.delegate?.remoteQueryKeyboards(keyboards: keyboards)
        self.comm?.removeCommand(command: self)
    }
}
