//
//  ATSession.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/7.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

protocol ATSessionDelegate {
    func sessionDidCreate(_ session: ATSession)
    func sessionDidFailToCreate(_ error: ATError)
    func sessionDidTerminate(_ error: ATError)
    func sessionDidFailToSend(_ error: ATError)
    func sessionDidReceive(_ data: Data)
    func sessionDidFailToReceive(_ error: ATError)
}

class ATSession : NSObject, ATDeviceDelegate {
    
    var alive: Bool = false
    
    private var device: ATDevice
    private var securityProtocol: ATSecurityProtocol
    private var delegate: ATSessionDelegate
    
    private static var initializingSessions: [ATSession] = []
    
    private init(Device device: ATDevice, Protocol securityProtocol: ATSecurityProtocol, Delegate delegate: ATSessionDelegate) {
        self.device = device
        self.securityProtocol = securityProtocol
        self.delegate = delegate
    }
    
    static func createSession<T: ATSecurityProtocol>(Device device: ATDevice, Protocol securityProtocol: T.Type, Delegate delegate: ATSessionDelegate) {
        let session = ATSession(Device: device, Protocol: securityProtocol.init(), Delegate: delegate)
        session.setup()
        ATSession.initializingSessions.append(session)
    }
    
    func setup() {
        self.device.delegate = self
        if self.device.connected {
            self.securityProtocol.setupSession(self.device) { (_ complete: Bool, _ error: ATError?) in
                self.alive = complete
                complete ? self.delegate.sessionDidCreate(self) : self.delegate.sessionDidFailToCreate(error!)
                if let index = ATSession.initializingSessions.firstIndex(of: self) {
                    ATSession.initializingSessions.remove(at: index)
                }
            }
        }
        else {
            self.device.connect()
        }
    }
    
    func send(_ data: Data) {
        if let encData = self.securityProtocol.encode(data) {
            //ATLog.debug("Send Session Data:\n\(encData as NSData)")
            self.device.send(encData) { (_ response: Data?, _ error: ATError?) in
                if response == nil {
                    if error == .failToReceive {
                        self.delegate.sessionDidFailToReceive(error!)
                    }
                    else {
                        self.delegate.sessionDidFailToSend(error!)
                    }
                }
                else if let decData = self.securityProtocol.decode(response!) {
                    self.delegate.sessionDidReceive(decData)
                }
                else {
                    self.delegate.sessionDidFailToReceive(.failToDecode)
                }
            }
        }
        else {
            self.delegate.sessionDidFailToSend(.failToEncode)
        }
    }
    
    // MARK: - ATDeviceDelegate
    
    func deviceDidConnect(_ device: ATDevice) {
        setup()
    }
    
    func deviceDidDisconnect(_ device: ATDevice) {
        self.alive = false
        self.delegate.sessionDidTerminate(.disconnection)
    }
    
    func deviceDidFailToConnect(_ device: ATDevice) {
        self.alive = false
        self.delegate.sessionDidFailToCreate(.failToConnect)
        if let index = ATSession.initializingSessions.firstIndex(of: self) {
            ATSession.initializingSessions.remove(at: index)
        }
    }
    
}
