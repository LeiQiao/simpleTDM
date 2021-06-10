//
//  LogWindow.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/27.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa
import SwiftyBeaver

class LogWindowController: NSWindowController, NSTableViewDataSource, NSSearchFieldDelegate {
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var levelSegments: NSSegmentedControl!
    @IBOutlet var searchBar: NSSearchField!
    @IBOutlet var clearButton: NSButton!
    var timer: Timer?
    var allLogs: [[String]] = []
    var searchLogs: [[String]] = []

    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.updateLogContent()
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (Timer) in
            self.updateLogContent()
        })
        
        self.window?.makeFirstResponder(self.searchBar)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        self.timer?.invalidate()
        return true
    }
    
    func updateLogContent() {
        let fileDestination = log.destinations.first as! FileDestination
        guard let fileURL = fileDestination.logFileURL else {
            return
        }
        let content = try? String(contentsOf: fileURL)
        self.formatLogString(content ?? "")
    }
    
    func formatLogString(_ logString: String) {
        var logs: [[String]] = []
        for log in logString.components(separatedBy: CharacterSet.newlines) {
            var fetchResult = self.fetchStringWithWritespace(log)
            guard let timeString = fetchResult.0 else {
                continue
            }
            fetchResult = self.fetchStringWithWritespace(fetchResult.1)
            guard let levelString = fetchResult.0 else {
                continue
            }
            fetchResult = self.fetchStringWithWritespace(fetchResult.1)
            guard let funcString = fetchResult.0 else {
                continue
            }
            fetchResult = self.fetchStringWithWritespace(fetchResult.1)
            let infoString = fetchResult.1
            
            logs.append([timeString, self.trimTermColor(levelString), funcString, infoString])
        }
        self.allLogs = logs.reversed()
        self.updateSearchContent()
        
        self.clearButton.isEnabled = self.allLogs.count > 0
    }
    
    func fetchStringWithWritespace(_ str: String) -> (String?, String) {
        guard let writespaceIndex = str.firstIndex(of: Character(" ")) else {
            return (nil, str)
        }
        let strSuffix = str[str.index(after: writespaceIndex)...]
        return (String(str[..<writespaceIndex]), String(strSuffix))
    }
    
    func trimTermColor(_ str: String) -> String {
        guard let mIndex = str.firstIndex(of: Character("m")) else {
            return str
        }
        let trimLeft = String(str[str.index(after: mIndex)...])
        guard let rIndex = trimLeft.firstIndex(of: Character("\u{1b}")) else {
            return trimLeft
        }
        let trimRight = String(trimLeft[..<rIndex])
        return trimRight
    }
    
    func updateSearchContent() {
        let selVerbose = self.levelSegments.isSelected(forSegment: 0)
        let selInfo = self.levelSegments.isSelected(forSegment: 1)
        let selWarning = self.levelSegments.isSelected(forSegment: 2)
        let selError = self.levelSegments.isSelected(forSegment: 3)
        let searchText = self.searchBar.stringValue
        
        if selVerbose && selInfo && selWarning && selError && searchText.count == 0 {
            self.searchLogs = self.allLogs
            self.tableView.reloadData()
            return
        }
        
        var logs: [[String]] = []
        for log in self.allLogs {
            if !selVerbose && log[1].lowercased() == "verbose" {
                continue
            }
            if !selInfo && log[1].lowercased() == "info" {
                continue
            }
            if !selWarning && log[1].lowercased() == "warning" {
                continue
            }
            if !selError && log[1].lowercased() == "error" {
                continue
            }
            if searchText.count > 0 && log[3].range(of: searchText) == nil {
                continue
            }
            logs.append(log)
        }
        self.searchLogs = logs
        self.tableView.reloadData()
    }
    
    @IBAction func segmentChanged(sender: Any) {
        self.updateSearchContent()
    }
    
    func controlTextDidChange(_ obj: Notification) {
        self.updateSearchContent()
    }
    
    @IBAction func clearButtonClicked(sender: Any) {
        let fileDestination = log.destinations.first as! FileDestination
        _ = fileDestination.deleteLogFile()
        self.updateLogContent()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.searchLogs.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let identifier = tableColumn?.identifier else {
            return nil
        }
        let col = tableView.column(withIdentifier: identifier)
        if row >= self.searchLogs.count || col >= 4 {
            return nil
        }
        return self.searchLogs[row][col]
    }
}
