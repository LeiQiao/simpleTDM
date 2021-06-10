//
//  ChooseKeyboardWindow.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/19.
//  Copyright © 2018 lei.qiao. All rights reserved.
//

import Cocoa

protocol ChooseKeyboardDelegate {
    func selectedKeyboard(name: String?, address: String?, object: BlueKeyboard?)
}

class ChooseKeyboardWindowController: NSWindowController, NSBrowserDelegate, NSWindowDelegate {
    open var delegate: ChooseKeyboardDelegate?
    var localKeyboards: [BlueKeyboard] = []
    var remoteKeyboards: [[String: String]] = []
    @IBOutlet weak var browser: NSBrowser!
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let delegate = self.delegate else {
            return true
        }
        delegate.selectedKeyboard(name: nil, address: nil, object: nil)
        return true
    }
    
    open func setKeyboards(local: [BlueKeyboard], remote: [[String: String]]) {
        self.localKeyboards = local
        self.remoteKeyboards = remote
    }
    
    func browser(_ sender: NSBrowser, numberOfRowsInColumn column: Int) -> Int {
        if column == 0 {
            return self.localKeyboards.count + self.remoteKeyboards.count
        }
        return 0
    }
    
    func browser(_ browser: NSBrowser, heightOfRow row: Int, inColumn columnIndex: Int) -> CGFloat {
        return 60
    }
    
    func browser(_ sender: NSBrowser, willDisplayCell cell: Any, atRow row: Int, column: Int) {
        let browserCell = cell as! NSBrowserCell
        if row < self.localKeyboards.count {
            browserCell.title = self.localKeyboards[row].getName() + " (local)"
        } else {
            browserCell.title = (self.remoteKeyboards[row-self.localKeyboards.count]["name"] ?? "") + " (remote)"
        }
        browserCell.isLeaf = true
    }
    
    @IBAction func selectedItem(_ item: Any) {
        guard let delegate = self.delegate else {
            return
        }
        
        var selectedRow = self.browser.selectedRow(inColumn: 0)
        
        if selectedRow < self.localKeyboards.count {
            let selectedKeyboard = self.localKeyboards[selectedRow]
            delegate.selectedKeyboard(name: selectedKeyboard.getName(),
                                      address: selectedKeyboard.getAddress(),
                                      object: selectedKeyboard)
        } else {
            selectedRow -= self.localKeyboards.count
            let selectedKeyboard = self.remoteKeyboards[selectedRow]
            delegate.selectedKeyboard(name: selectedKeyboard["name"],
                                      address: selectedKeyboard["address"],
                                      object: nil)
        }
        close()
    }
}
