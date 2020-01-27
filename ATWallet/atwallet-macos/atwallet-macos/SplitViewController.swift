//
//  SplitViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/8/8.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class SplitViewController: NSSplitViewController {
    
    var masterViewController: NSViewController {
        return self.splitViewItems[0].viewController
    }
    
    var detailViewController: NSViewController {
        get {
            return self.splitViewItems[1].viewController
        }
        set {
            self.splitViewItems[1] = NSSplitViewItem(viewController: newValue)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        AppController.shared.setSplitViewController(self)
    }
    
    override func viewWillAppear() {
        NSApp.mainWindow?.backgroundColor = AppController.BackgroundColor
    }
    
}
