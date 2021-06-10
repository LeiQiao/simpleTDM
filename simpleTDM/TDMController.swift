//
//  TDMController.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/27.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa

class TDMController: NSObject, SettingDelegate, ConnectKeyboardCommandDelegate, ReleaseKeyboardCommandDelegate {
    var comm: Communication!
    
    var statusMenu: NSStatusItem?
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet weak var statusItem: NSMenuItem!
    @IBOutlet weak var sendToItem: NSMenuItem!
    @IBOutlet weak var takeFromItem: NSMenuItem!
    @IBOutlet weak var copyIPItem: NSMenuItem!
    @IBOutlet weak var sleepItem: NSMenuItem!
    @IBOutlet weak var wakeItem: NSMenuItem!
    
    var settingWindow: SettingWindowController?
    var logWindow: LogWindowController?
    
//    init(comm: Communication) {
//        self.comm = comm
//        super.init()
//    }
    
    override init() {
        super.init()
    }
    
    override func awakeFromNib() {
        log.info("create controller")
        let app = NSApplication.shared.delegate as! AppDelegate
        app.controller = self
        if app.comm == nil {
            app.comm = Communication(delegate: app)
        }
        self.comm = app.comm!
        
        self.statusMenu = self.statusBarWithMenu(menu: self.menu)
        self.updateMenuStatus()
    }
    
    func updateMenuStatus() {
        log.info("update status menu")
        self.statusItem.title = "connection: "
        if TDMUtilities.sharedInstance.isMaster() {
            if TDMUtilities.sharedInstance.isInTargetDisplayMode() {
                self.statusItem.title += "connected"
            } else if self.comm.connected {
                self.statusItem.title += "ready"
            } else {
                self.statusItem.title += "not connected"
            }
        } else {
            if self.comm.connected {
                self.statusItem.title += "ready"
            } else {
                self.statusItem.title += "not connected"
            }
        }
        
        self.sendToItem.isEnabled = self.comm.connected
        self.takeFromItem.isEnabled = self.comm.connected
        self.copyIPItem.isEnabled = self.comm.connected
        self.sleepItem.isEnabled = self.comm.connected
        self.wakeItem.isEnabled = self.comm.connected
        
        if TDMUtilities.sharedInstance.isSlave() {
            self.sleepItem.isHidden = true
            self.wakeItem.isHidden = true
        }
    }
    
    func statusBarWithMenu(menu: NSMenu) -> NSStatusItem {
        log.info("create status bar")
        let icon = NSImage(named: "StatusIcon")
        icon?.isTemplate = true
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.title = nil
        statusItem.image = icon
        statusItem.alternateImage = icon
        statusItem.highlightMode = true
        statusItem.menu = menu
        return statusItem
    }
    
    @IBAction func toggleSendKeyboarad(menuItem: NSMenuItem) {
        log.info("send keyboard to remote pressed")
        ConnectKeyboardCommand(comm: self.comm, delegate: self).execute(keyboardAddress: nil)
    }
    
    @IBAction func toggleTakeKeyboard(menuItem: NSMenuItem) {
        log.info("take keyboard from remote pressed")
        ReleaseKeyboardCommand(comm: self.comm, delegate: self).execute(keyboardAddress: nil)
    }
    
    @IBAction func toggleCopyIP(menuItem: NSMenuItem) {
        log.info("copy remote IP pressed")
        guard let remoteIP = self.comm.remoteIP else {
            log.error("copy remote IP but not connect yet.")
            let alert = NSAlert()
            alert.messageText = "simpleTDM"
            alert.informativeText = "unable copy remote IP, remote not connected."
            alert.alertStyle = NSAlert.Style.critical
            alert.runModal()
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(remoteIP, forType: NSPasteboard.PasteboardType.string)
        
        let alert = NSAlert()
        alert.messageText = "simpleTDM"
        alert.informativeText = "remote IP \(remoteIP) copied to pasteboard."
        alert.alertStyle = NSAlert.Style.informational
        alert.runModal()
    }
    
    @IBAction func toggleSleepRemoteScreen(menuItem: NSMenuItem) {
        SleepCommand(comm: self.comm).execute()
    }
    
    @IBAction func toggleWakeRemoteScreen(menuItem: NSMenuItem) {
        WakeCommand(comm: self.comm).execute()
    }
    
    @IBAction func toggleSetting(menuItem: NSMenuItem) {
        log.info("settings pressed")
        self.settingWindow?.close()
        self.settingWindow = SettingWindowController(windowNibName: "SettingWindow")
        self.settingWindow?.delegate = self
        self.settingWindow?.window?.makeKeyAndOrderFront(nil)
        self.settingWindow?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func toggleLog(menuItem: NSMenuItem) {
        log.info("log pressed")
        self.logWindow?.close()
        self.logWindow = LogWindowController(windowNibName: "LogWindow")
        self.logWindow?.window?.makeKeyAndOrderFront(nil)
        self.logWindow?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func remoteConnectKeyboard(success: Bool, reason: String) {
        log.info("remoteConnectKeyboard: \(success) \(reason)")
        if success {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "simpleTDM"
        alert.informativeText = "unable send keyboard to remote, \(reason)."
        alert.alertStyle = NSAlert.Style.critical
        alert.runModal()
    }
    
    func remoteReleaseKeyboard(success: Bool, reason: String) {
        log.info("remoteReleaseKeyboard: \(success) \(reason)")
        if success {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "simpleTDM"
        alert.informativeText = "unable take keyboard from remote, \(reason)."
        alert.alertStyle = NSAlert.Style.critical
        alert.runModal()
    }
    
    func portDidChanged() {
        log.info("port did changed to: \(PreferenceUtilities.sharedInstance.port)")
        self.comm.changePort()
    }
}
