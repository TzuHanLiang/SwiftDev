//
//  ATCommandHandler.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/8.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

class ATCommandHandler : NSObject, ATSessionDelegate {
    
    private var device: ATDevice
    private var securityProtocol: ATSecurityProtocol.Type
    private var session: ATSession?
    private var cmdQueue: [AnyObject] = []
    private let dispatchQueue: DispatchQueue
    private var currentItem: AnyObject?
    
    private var currentCommand: ATCommand {
        get {
            if let cmd = self.currentItem as? ATCommand {
                return cmd
            }
            else if let bundle = self.currentItem as? ATCommandBundle {
                return bundle.command!
            }
            else {
                ATLog.error("This should not happen!")
                abort()
            }
        }
    }
    
    init<T: ATSecurityProtocol>(Device device: ATDevice, Protocol securityProtocol: T.Type) {
        self.device = device
        self.securityProtocol = securityProtocol
        self.dispatchQueue = DispatchQueue(label: "com.AuthenTrend.ATWalletKit.ATCommandHandler")
        super.init()
        self.device.delegate = nil
    }
    
    func enqueueCommand(_ command: ATCommand) {
        enqueue(command)
    }
    
    func enqueueCommandBundle(_ bundle: ATCommandBundle) {
        if bundle.count > 0 {
            enqueue(bundle)
        }
    }
    
    private func enqueue(_ command: AnyObject) {
        self.dispatchQueue.async {
            self.cmdQueue.append(command)
            if self.currentItem == nil {
                self.currentItem = self.dequeue()
                self.execute()
            }
        }
    }
    
    private func dequeue() -> AnyObject? {
        return self.cmdQueue.isEmpty ? nil : self.cmdQueue.removeFirst()
    }
    
    private func execute() {
        if self.currentItem == nil {
            return
        }
        
        if self.session == nil || self.session?.alive == false {
            ATSession.createSession(Device: self.device, Protocol: self.securityProtocol, Delegate: self)
            return
        }
        
        ATLog.debug("Send CMD:\n\(self.currentCommand.data as NSData)")
        self.session?.send(self.currentCommand.data)
    }
    
    private func executeNextCommand() {
        if (self.currentItem as? ATCommand) != nil {
            self.currentItem = dequeue()
            execute()
        }
        else if let bundle = self.currentItem as? ATCommandBundle {
            if !self.currentCommand.succeeded {
                self.currentItem = dequeue()
                execute()
            }
            else if let cmd = bundle.nextCommand() {
                ATLog.debug("Send CMD:\n\(cmd.data as NSData)")
                self.session?.send(cmd.data)
            }
            else {
                self.currentItem = dequeue()
                execute()
            }
        }
    }
    
    // MARK: - ATSessionDelegate
    
    func sessionDidCreate(_ session: ATSession) {
        self.dispatchQueue.async {
            self.session = session
            ATLog.debug("Send CMD:\n\(self.currentCommand.data as NSData)")
            session.send(self.currentCommand.data)
        }
    }
    
    func sessionDidFailToCreate(_ error: ATError) {
        self.dispatchQueue.async {
            self.currentCommand.resultHandler(nil, error)
            self.executeNextCommand()
        }
    }
    
    func sessionDidTerminate(_ error: ATError) {
        // ignore
    }
    
    func sessionDidFailToSend(_ error: ATError) {
        self.dispatchQueue.async {
            self.currentCommand.resultHandler(nil, error)
            self.executeNextCommand()
        }
    }
    
    func sessionDidReceive(_ data: Data) {
        self.dispatchQueue.async {
            self.currentCommand.handleResponse(data)
            self.executeNextCommand()
        }
    }
    
    func sessionDidFailToReceive(_ error: ATError) {
        self.dispatchQueue.async {
            self.currentCommand.resultHandler(nil, error)
            self.executeNextCommand()
        }
    }
    
}

