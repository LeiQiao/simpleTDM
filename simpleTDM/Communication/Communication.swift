//
//  Communication.swift
//  biu
//
//  Created by lei.qiao on 2018/11/21.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

protocol CommunicationDelegate {
    func remoteConnected()
    func remoteDisconnected()
    func remoteConflitWarning()
}

class Communication: NSObject, GCDAsyncUdpSocketDelegate {
    var connected: Bool = false
    var commSocket: GCDAsyncUdpSocket?
    
    var selfIP: String?
    var remoteIP: String?
    var remoteSecretKey: String?
    var broadcastAddress: String?
    var broadcastTimer: Timer?
    var heartBeatTimer: Timer?
    var receiveHeartBeatCount: Int = 0
    
    var connectedPort: UInt16 {
        get {
            guard let _port = self.commSocket?.connectedPort() else {
                return 0
            }
            return _port
        }
    }
    
    var delegate: CommunicationDelegate?
    
    var commands: [CommCommand] = []
    
    init(delegate: CommunicationDelegate?) {
        super.init()
        
        self.delegate = delegate
        self.connect()
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { (notify: Notification) in
            log.info("awake form sleep")
        }
    }
    
    func connect() {
        if self.commSocket != nil {
            self.disconnect()
        }
        self.commSocket = GCDAsyncUdpSocket(delegate: self,
                                            delegateQueue: DispatchQueue.main)
        self.commSocket?.setIPv6Enabled(false)
        
        do {
            try self.commSocket?.bind(toPort: PreferenceUtilities.sharedInstance.port)
            try self.commSocket?.enableBroadcast(true)
            try self.commSocket?.beginReceiving()
        } catch let error as NSError {
            log.error(error)
            return
        }
        
        log.info("create UDP connecting")
        
        self.updateWiFiAddress()
        
        log.info("ip: \(self.selfIP ?? "**error**")")
        log.info("broadcast address: \(self.broadcastAddress ?? "**error**")")
        
        // iMac 广播
        if TDMUtilities.sharedInstance.isSlave() {
            self.startBroadcast()
        }
        self.startDetectHeartBeat()
    }
    
    func disconnect() {
        log.info("destroy UDP connecting")
        self.heartBeatTimer?.invalidate()
        self.heartBeatTimer = nil
        self.broadcastTimer?.invalidate()
        self.broadcastTimer = nil
        self.commSocket?.setDelegate(nil)
        self.commSocket?.close()
        self.commSocket = nil
    }
    
    func updateWiFiAddress() {
        let netInfo = NetworkUtilities.sharedInstance.getMyWiFiAddress()
        self.selfIP = netInfo?.ip
        self.broadcastAddress = netInfo?.broadcast
    }
    
    func changePort() {
        log.info("recreate UDP connecting")
        self.disconnect()
        self.connect()
    }
    
    func didConnected(remoteIP: String, remoteSecretKey: String) {
        if self.connected && self.remoteIP == remoteIP && self.remoteSecretKey == remoteSecretKey {
            return
        }
        self.connected = true
        self.remoteIP = remoteIP
        self.remoteSecretKey = remoteSecretKey
        self.delegate?.remoteConnected()
    }
    
    func didDisconnected() {
        if !self.connected {
            return
        }
        self.connected = false
        self.remoteIP = nil
        self.remoteSecretKey = nil
        for cmd in self.commands {
            cmd.terminate()
        }
        self.commands = []
        self.delegate?.remoteDisconnected()
    }
    
    func startBroadcast() {
        self.heartBeatTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (Timer) in
            self.updateWiFiAddress()
            self.sendGreating()
        })
    }
    
    func startDetectHeartBeat() {
        self.heartBeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { (Timer) in
            if self.receiveHeartBeatCount == 0 {
                self.didDisconnected()
            }
            self.receiveHeartBeatCount = 0
        })
    }
    
    func sendGreating() {
        log.verbose("sending greating message")
        guard let broadcastAddress = self.broadcastAddress else {
            log.verbose("broadcast address is nil, reconnecting")
            return
        }
        let remoteSecretKey = self.remoteSecretKey ?? ""
        let message: [String: String] = [
            "masterSecretKey": remoteSecretKey,
            "slaveSecretKey": PreferenceUtilities.sharedInstance.secretKey
        ]
        self.sendMessage(to: broadcastAddress, command: "GRT", message:message)
    }
    
    func recvGreating(from: String, message: String) {
        log.verbose("receive greating message")
        guard let jsonObject = self.unwarpJSON(jsonString: message) else {
            return
        }
        let selfSecretKey = (jsonObject as! [String: String])["masterSecretKey"] ?? ""
        let remoteSecretKey = (jsonObject as! [String: String])["slaveSecretKey"] ?? ""
        
        // connected to this computer
        if selfSecretKey == PreferenceUtilities.sharedInstance.secretKey {
            if self.remoteSecretKey == nil {
                // when master app is restart
                self.didConnected(remoteIP: from, remoteSecretKey: remoteSecretKey)
            } else if self.remoteSecretKey == remoteSecretKey {
                // when slave ip changed
                self.remoteIP = from
                self.didConnected(remoteIP: from,
                                  remoteSecretKey: remoteSecretKey)
            } else {
                log.verbose("\(from)'s master is this MBP but this computer has connected to other iMac")
                sendConflict(to: from)
                self.delegate?.remoteConflitWarning()
                return
            }
        } else if selfSecretKey != "" {
            log.verbose("other iMac connected other MBP, may be at least 4 computers communicating in port \(PreferenceUtilities.sharedInstance.port), please change port")
            sendConflict(to: from)
            self.delegate?.remoteConflitWarning()
            return
        } else { // selfSecretKey == ""
            if self.remoteSecretKey == nil {
                // connected waiting for received remote message to call 'didConnected'
                self.remoteIP = from
            }
            else if self.remoteSecretKey != remoteSecretKey {
                log.verbose("other iMac is communicating in port \(PreferenceUtilities.sharedInstance.port), please change port")
                sendConflict(to: from)
                self.delegate?.remoteConflitWarning()
                return
            }
        }
        
        self.receiveHeartBeatCount += 1
        
        var slaveSecretKey = remoteSecretKey
        if self.remoteSecretKey != nil {
            slaveSecretKey = self.remoteSecretKey!
        }
        let ackMessage = [
            "masterSecretKey": PreferenceUtilities.sharedInstance.secretKey,
            "slaveSecretKey": slaveSecretKey
        ]
        self.ackMessage(command: "GRT", message: ackMessage)
    }
    
    func ackGreating(from: String, message: String) {
        log.verbose("receive ack greating message")
        guard let message = self.unwarpJSON(jsonString: message) else {
            return
        }
        let remoteSecretKey = (message as! [String: String])["masterSecretKey"] ?? ""
        
        self.receiveHeartBeatCount += 1
        
        self.didConnected(remoteIP: from, remoteSecretKey: remoteSecretKey)
    }
    
    func sendConflict(to: String) {
        self.sendMessage(to: to, command: "CFT", message: "")
    }
    
    func recvConflict(from: String, message: String) {
        print("may be more then 2 computers communicating in port \(PreferenceUtilities.sharedInstance.port), please change port")
        self.delegate?.remoteConflitWarning()
    }
    
    func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
        if error == nil {
            return
        }
        log.error("\(error!)")
        
        // try reconnect
        self.changePort()
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
        log.verbose("socket did not send data")
        if error != nil {
            log.error("\(error!)")
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        guard let message = String(data: data, encoding: String.Encoding.utf8) else {
            print("receive unknown message")
            return
        }
        var host: NSString?
        var port: UInt16 = 0
        var family: Int32 = 0
        GCDAsyncUdpSocket.getHost(&host, port: &port, family: &family, fromAddress: address)
        guard let hostString = host as String? else {
            print("unable get host")
            return
        }
        // ignore self message
        if hostString == self.selfIP {
            return
        }
        if message.count == 0 {
            print("receive empty message")
        } else {
            self.handleMessage(from: hostString, message: message)
        }
    }
    
    func handleMessage(from: String, message: String) {
        let command = String(message.prefix(3))
        let message = String(message.suffix(message.count - 4))
        
        if command == "ACK" {
            let command = String(message.prefix(3))
            let message = String(message.suffix(message.count - 4))
            
            log.verbose("receive ack command: \(command) message: \(message)")
            
            if command == "GRT" {
                self.ackGreating(from: from, message: message)
            } else if command == "CFT" {
                // self.ackConflict(from:from, message: message)
            } else {
                for cmd in self.commands {
                    if command == cmd.command {
                        cmd.handleACKMessage(message: message)
                        return
                    }
                }
            }
            return
        }
        
        log.verbose("receive command: \(command) message: \(message)")
        
        if command == "GRT" {
            self.recvGreating(from: from, message: message)
        } else if command == "CFT" {
            self.recvConflict(from: from, message: message)
        } else {
            for cmd in self.commands {
                if command == cmd.command {
                    cmd.handleMessage(message: message)
                    return
                }
            }
            
            // no command in command chain, create it
            guard let cmd = CommandFactor.command(command: command, comm: self) else {
                return
            }
            self.appendCommand(command: cmd)
            cmd.handleMessage(message: message)
        }
    }
    
    func sendMessage(command: String, message: Any) {
        guard let remoteIP = self.remoteIP else {
            log.error("unable send message because not connected")
            return
        }
        self.sendMessage(to: remoteIP, command: command, message: message)
    }
    
    func sendMessage(to: String, command: String, message: Any) {
        var messageString: String
        if message is String {
            messageString = message as! String
        } else {
            messageString = self.warpJSON(object: message)
        }
        guard let messageData = "\(command)|\(messageString)".data(using: String.Encoding.utf8) else {
            log.error("unable pack message data for command: \(command)")
            return
        }
        guard let commSocket = self.commSocket else {
            log.error("unable send message because not connected")
            return
        }
        commSocket.send(messageData,
                        toHost: to,
                        port: PreferenceUtilities.sharedInstance.port,
                        withTimeout: -1,
                        tag: 1)
    }
    
    func ackMessage(command: String, message: Any) {
        self.sendMessage(command: "ACK|"+command, message: message)
    }
    
    func warpJSON(object: Any) -> String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: object, options: []) else {
            log.error("unable warp to json \(object)")
            return ""
        }
        guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            log.error("unable warp to json \(jsonData)")
            return ""
        }
        return jsonString
    }
    
    func unwarpJSON(jsonString: String) -> Any? {
        guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
            log.error("unable unwarp json \(jsonString)")
            return nil
        }
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
            log.error("unable unwarp json \(jsonString)")
            return nil
        }
        return jsonObject
    }
    
    func appendCommand(command: CommCommand) {
        for cmd in self.commands {
            if type(of: cmd) == type(of: command) {
                if Date(timeIntervalSinceNow: 30) > cmd.initTime {
                    log.warning("command \(cmd.command) has expired, \(cmd.initTime)")
                    self.removeCommand(command: cmd)
                    self.commands.append(command)
                    return
                }
                else {
                    log.warning("command \(command.command) is already running.")
                    return
                }
            }
        }
        self.commands.append(command)
    }
    
    func removeCommand(command: CommCommand) {
        if self.commands.count == 0 {
            return
        }
        for i in 0...self.commands.count-1 {
            if self.commands[i].command == command.command {
                self.commands.remove(at: i)
                return
            }
        }
    }
}

class CommCommand : NSObject {
    weak var comm: Communication?
    var command: String
    var initTime: Date
    
    
    init(comm: Communication) {
        self.command = ""
        self.comm = comm
        self.initTime = Date()
    }
    
    func execute() {
    }
    
    func terminate() {
    }
    
    func sendMessage(message: Any) {
        if self.command == "" {
            print("command is nil")
        }
        self.comm?.sendMessage(command: self.command, message: message)
    }
    
    func ackMessage(message: Any) {
        if self.command == "" {
            print("command is nil")
        }
        self.comm?.ackMessage(command: self.command, message: message)
    }
    
    func handleMessage(message: String) {
    }
    
    func handleACKMessage(message: String) {
    }
}
