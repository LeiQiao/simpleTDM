//
//  CommandFactor.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/22.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa


class CommandFactor: NSObject {
    
    static func command(command: String, comm: Communication) -> CommCommand? {
        log.verbose("create command \(command) handler")
        switch command {
        case QueryKeyboardCommandKey:
            return QueryKeyboardCommand(comm: comm, delegate: nil)
        case ConnectKeyboardCommandKey:
            return ConnectKeyboardCommand(comm: comm, delegate: nil)
        case ReleaseKeyboardCommandKey:
            return ReleaseKeyboardCommand(comm: comm, delegate: nil)
        case EnterTDMCommandKey:
            return EnterTDMCommand(comm: comm, delegate: nil)
        case SleepCommandKey:
            return SleepCommand(comm: comm)
        case WakeCommandKey:
            return WakeCommand(comm: comm)
        default:
            return nil
        }
    }

}
