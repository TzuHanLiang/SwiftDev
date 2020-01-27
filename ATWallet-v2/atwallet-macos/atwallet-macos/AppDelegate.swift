//
//  AppDelegate.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/8/8.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppController.shared.popSplitDetailViewToRootViewController()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sender.terminate(sender)
        }
        return false
    }

}

