//
//  AppDelegate.swift
//  LaunchHelper
//
//  Created by lei.qiao on 2018/11/26.
//  Copyright © 2018 LoveC. All rights reserved.
//

import Cocoa
import SwiftyBeaver


let log = SwiftyBeaver.self

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let file = FileDestination()
        file.logFileURL = URL(fileURLWithPath: "/tmp/simpleTDM.log")
        log.addDestination(file)
        
        let mainAppIdentifier = "com.LoveC.simpleTDM"
        let running = NSWorkspace.shared.runningApplications
        var alreadyRunning = false
        
        log.info("simpleTDM LaunchHelper running")
        
        for app in running {
            if app.bundleIdentifier == mainAppIdentifier {
                alreadyRunning = true
                break
            }
        }
        
        if !alreadyRunning {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(AppDelegate.terminate), name: Notification.Name(rawValue: "killhelper"), object: mainAppIdentifier)
            
            let path = Bundle.main.bundlePath as NSString
            log.info("simpleTDM LaunchHelper execute path: " + (path as String))
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("simpleTDM") //main app name
            
            let newPath = NSString.path(withComponents: components)
            log.info("simpleTDM execute path: " + newPath)
            NSWorkspace.shared.launchApplication(newPath)
        } else {
            log.info("simpleTDM already runnning, quit LaunchHelper")
            self.terminate()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func terminate() {
        // NSLog("I'll be back!")
        NSApp.terminate(nil)
    }
}

