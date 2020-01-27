//
//  ATCommandBundle.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/8.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

class ATCommandBundle : NSObject {

    private var index: Int = 0
    private var cmdQueue: [ATCommand] = []
    
    var count: Int { get { return self.cmdQueue.count } }
    
    var command: ATCommand? { get { return  (index < cmdQueue.count) ? cmdQueue[index] : nil } }
    
    func appendCommand(_ command: ATCommand) -> ATCommandBundle {
        self.cmdQueue.append(command)
        return self
    }
    
    func nextCommand() -> ATCommand? {
        index += 1
        return self.command
    }
    
}
