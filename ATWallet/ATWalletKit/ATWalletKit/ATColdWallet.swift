//
//  ATColdWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/5.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

public class ATColdWalletDelegate : NSObject {
    
    public var coldWalletDidFailToConnect: () -> () = { ATLog.debug("\(#function) needs to be implemented.") }
    
    public var coldWalletDidFailToExecuteCommand: (_ error: ATError) -> () = { (error) in ATLog.debug("\(#function) needs to be implemented.") }
    
    public var coldWalletNeedsLoginWithFingerprint: () -> () = { ATLog.debug("\(#function) needs to be implemented.") }
    
    public var coldWalletDidGetVersionInfo: (_ fwVersion: Data, _ seVersion: Data) -> () = { (fwVersion, seVersion) in }
    
    public var coldWalletDidGetDeviceInfo: (_ deviceName: String, _ batteryLevel: UInt, _ batteryCharging: Bool) -> () = { (deviceName, batteryLevel, batteryCharging) in }

    public var coldWalletHasEnrolledFingerprint: (_ enrolled: Bool) -> () = { (enrolled) in }
    
    public var coldWalletIsAbleToAddFingerprint: (_ able: Bool) -> () = { (able) in }
    
    public var coldWalletDidStartFingerprintEnrollment: () -> () = {}
    
    public var coldWalletDidCancelFingerprintEnrollment: () -> () = {}
    
    public var coldWalletDidFinishFingerprintEnrollment: () -> () = {}
    
    public var coldWalletDidUpdateFingerprintEnrollmentState: (_ progress: UInt8, _ placeFingerRequired: Bool) -> () = { (progress, placeFingerRequired) in }
    
    public var coldWalletDidStartLoginWithFingerprint: () -> () = {}
    
    public var coldWalletDidFinishLoginWithFingerprint: () -> () = {}
    
    public var coldWalletDidCancelLoginWithFingerprint: () -> () = {}
    
    public var coldWalletDidStartFingerprintVerification: () -> () = {}
    
    public var coldWalletDidFinishFingerprintVerification: () -> () = {}
    
    public var coldWalletDidUpdateFingerprintVerificationState: (_ matched: Bool?, _ placeFingerRequired: Bool) -> () = { (matched, placeFingerRequired) in }
    
    public var coldWalletDidLogin: (_ hdwallet: ATHDWallet?) -> () = { (hdwallet) in }
    
    public var coldWalletDidFailToLogin: () -> () = {}
    
    public var coldWalletDidLogout: () -> () = {}
    
    public var coldWalletDidInitializeHDWallet: (_ hdwallet: ATHDWallet?) -> () = { (hdwallet) in }
    
    public var coldWalletDidFailToInitializeHDWallet: () -> () = {}
    
    public var coldWalletDidRecoverHDWallet: (_ hdwallet: ATHDWallet?) -> () = { (hdwallet) in }
    
    public var coldWalletDidFailToRecoverHDWallet: () -> () = {}
    
    public var coldWalletDidCreateWallet: (_ wallet: ATCryptocurrencyWallet) -> () = { (wallet) in}
    
    public var coldWalletDidFailToCreateWallet: () -> () = {}
    
    public var coldWalletDidRemoveWallet: () -> () = {}
    
    public var coldWalletDidFailToRemoveWallet: () -> () = {}
    
    public var coldWalletDidGetWalletInfo: (_ purpose: UInt32, _ coinType: UInt32, _ account: UInt32, _ balance: ATUInt256, _ name: String, _ numberOfExtKey: UInt32, _ numberOfIntKey: UInt32, _ timestamp: UInt32, _ uniqueId: [UInt8], _ currencyType: UInt32) -> () = { (purse, coinType, account, balance, name, numberOfExtKey, numberOfIntKey, timestamp, uniqueId, currencyType) in}
    
    public var coldWalletDidGetWalletExternalKeyInfo: (_ key: [UInt8]) -> () = { (key) in }
    
    public var coldWalletDidGetWalletInternalKeyInfo: (_ key: [UInt8]) -> () = { (key) in }
    
    public var coldWalletDidPrepareToSignData: () -> () = {}
    
    public var coldWalletDidSignData: (_ signatures: [Data]) -> () = { (signatures) in }
    
    public var coldWalletDidUpdateWalletBalance: () -> () = {}
    
    public var coldWalletDidUpdateWalletExternalKeyIndex: () -> () = {}
    
    public var coldWalletDidUpdateWalletInternalKeyIndex: () -> () = {}
    
    public var coldWalletDidFactoryReset: () -> () = {}
    
    public var coldWalletDidResetHDWallets: () -> () = {}
    
    public var coldWalletDidGetHDWalletExtendedPublicKeyInfo: (_ key: [UInt8], _ chainCode: [UInt8], _ fingerprint: UInt32) -> () = { (key, chainCode, fingerprint) in }
    
    public var coldWalletDidSetLanguage: () -> () = {}
        
    public var coldWalletDidUnbindLoginFingerprints: () -> () = {}
    
    public var coldWalletDidCancelLoginFingerprints: () -> () = {}
    
    public var coldWalletDidStartBindingLoginFingerprints: () -> () = {}
    
    public var coldWalletDidBindLoginFingerprints: () -> () = {}
    
    public var coldWalletDidFailToBindLoginFingerprints: () -> () = {}
    
    public var coldWalletDidStartToVerifyBoundLoginFingerprints: () -> () = {}
    
    public var coldWalletDidVerifyBoundLoginFingerprints: () -> () = {}
    
    public var coldWalletDidFailToVerifyBoundLoginFingerprints: () -> () = {}
    
    public var coldWalletDidStartFirmwareOTA: () -> () = {}
        
    public var coldWalletDidSendFirmwareData: () -> () = {}
    
    public var coldWalletDidFinishFirmwareOTA: () -> () = {}
    
    public var coldWalletDidCancelFirmwareOTA: () -> () = {}
    
    public var coldWalletDidCalibrateFingerprintSensor: () -> () = {}
    
    public var coldWalletDidStartFingerprintDeletion: () -> () = {}
    
    public var coldWalletDidFinishFingerprintDeletion: (_ fpids: [UInt32]?) -> () = { (fpids) in }
    
    public var coldWalletDidCancelFingerprintDeletion: () -> () = {}
    
    public var coldWalletDidChangeHDWalletName: () -> () = {}
    
    public var coldWalletDidChangeWalletName: (_ accountIndex: UInt32) -> () = { (accountIndex) in }
        
    public override init() {}
    
    public init(_ initializer: (ATColdWalletDelegate) -> ()) {
        super.init()
        initializer(self)
    }
}

public class ATColdWallet : NSObject {
    
    private var device: ATDevice
    private var commandHandler: ATCommandHandler
    private var registered: Bool = false
    private var initialEnroll: Bool = false
    private var _loggedIn: Bool = false
    private var lastTokenTimestamp: Date?
    private var _token: Data?
    private var token: Data? {
        get {
            guard let token = self._token, let timestamp = self.lastTokenTimestamp else { return nil }
            guard abs(timestamp.timeIntervalSinceNow) < (15 * 60) else { return nil } // token will expire after 15 minutes
            return token
        }
        set {
            self._token = newValue
            self.lastTokenTimestamp = (newValue == nil) ? nil : Date()
        }
    }
    
    internal(set) public var hdwallet: ATHDWallet?
    internal(set) public var loggedInHDWIndex: UInt8 = 0;
    internal(set) public var hdwInitState: [Bool] = []
    internal(set) public var batteryLevel: UInt?
    internal(set) public var batteryCharging: Bool?
    internal(set) public var loggedIn: Bool {
        get {
            !self.connected ? self._loggedIn = false : nil
            return self._loggedIn
        }
        set {
            self._loggedIn = newValue
        }
    }
    
    public var connected: Bool { get { return self.device.connected } }
    public var name: String { get { return self.device.name } }
    
    public enum Language : CaseIterable {
        case english
        case japanese
        
        public var code: String {
            get {
                switch self {
                case .english:
                    return "en"
                case .japanese:
                    return "ja"
                }
            }
        }
        
        public var id: UInt8 {
            get {
                switch self {
                case .english:
                    return 0x00
                case .japanese:
                    return 0x01
                }
            }
        }
    }
    
    public enum FirmwareType: UInt8 {
        case mcu = 0x01
        case cos = 0x02
    }
    
    public init<T: ATSecurityProtocol>(Device device: ATDevice, Protocol securityProtocol: T.Type) {
        self.device = device
        self.commandHandler = ATCommandHandler(Device: device, Protocol: securityProtocol)
        super.init()
    }
    
    private func genTokenLoginCmd(Delegate delegate: ATColdWalletDelegate) -> ATCommand {
        ATLog.debug("\(#function)")
        let command = ATCLoginWithToken(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let info = data as! ATCLoginWithToken.Info
            self.loggedIn = info.loggedIn
            if !info.loggedIn {
                DispatchQueue.main.async {
                    delegate.coldWalletNeedsLoginWithFingerprint()
                }
            }
        })
        command.cmdData = self.token
        return command
    }
    
    private func loginWithToken(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCLoginWithToken(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let info = data as! ATCLoginWithToken.Info
            self.loggedIn = info.loggedIn
            self.hdwInitState = info.masterNodeExistence
            
            if !self.loggedIn {
                self.hdwallet = nil
                self.token = nil
                DispatchQueue.main.async {
                    delegate.coldWalletDidFailToLogin()
                }
            }
            else if !info.masterNodeExistence[Int(info.hdwIndex)] {
                self.hdwallet = nil
                self.loggedInHDWIndex = info.hdwIndex
                DispatchQueue.main.async {
                    delegate.coldWalletDidLogin(nil)
                }
            }
            else if self.hdwallet == nil {
                self.loggedInHDWIndex = info.hdwIndex
                self.hdwallet = ATHDWallet(Name: info.name, ColdWallet: self, HDWIndex: info.hdwIndex, ExistedWallets: info.existedAccountNumber)
                DispatchQueue.main.async {
                    delegate.coldWalletDidLogin(self.hdwallet)
                }
            }
            else {
                self.loggedInHDWIndex = info.hdwIndex
                self.hdwallet?.numberOfWallet = info.existedAccountNumber
                DispatchQueue.main.async {
                    delegate.coldWalletDidLogin(self.hdwallet)
                }
            }
        })
        command.cmdData = self.token
        self.commandHandler.enqueueCommand(command)
    }
    
    public func disconnect() {
        ATLog.debug("\(#function)")
        self.device.disconnect()
        for wallet in self.hdwallet?.wallets ?? [] {
            wallet.deinitWallet()
        }
        self.hdwallet = nil
        self.token = nil
    }
    
    public func updateBatteryState(_ completion: (() -> ())?) {
        getDeviceInfo(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidGetDeviceInfo = { (deviceName, batteryLevel, batteryCharging) in
                self.batteryLevel = batteryLevel
                self.batteryCharging = batteryCharging
                DispatchQueue.main.async {
                    completion?()
                }
            }
        })
    }
    
    public func getVersionInfo(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let _ = self.loggedIn // just for update login state
        self.commandHandler.enqueueCommand(ATCQueryVersionInfo(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let info = data as! ATCQueryVersionInfo.Info
            
            DispatchQueue.main.async {
                delegate.coldWalletDidGetVersionInfo(info.fwVersion, info.seVersion)
            }
        }))
    }
    
    public func getDeviceInfo(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let _ = self.loggedIn // just for update login state
        self.commandHandler.enqueueCommand(ATCQueryDeviceInfo(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let info = data as! ATCQueryDeviceInfo.Info
            
            DispatchQueue.main.async {
                self.batteryLevel = info.batteryLevel
                self.batteryCharging = info.batteryCharging
                delegate.coldWalletDidGetDeviceInfo(info.deviceName, info.batteryLevel, info.batteryCharging)
            }
        }))
    }
    
    public func hasFingerprintBeenEnrolled(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let _ = self.loggedIn // just for update login state
        self.commandHandler.enqueueCommand(ATCQueryEnrolledFp(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let enrolled = data as! Bool
            self.registered = enrolled
            if !self.registered {
                self.initialEnroll = true
            }
            DispatchQueue.main.async {
                delegate.coldWalletHasEnrolledFingerprint(enrolled)
            }
        }))
    }
    
    public func isAbleToAddFingerprint(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCQueryAllowFpEnroll(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let able = data as! Bool
            DispatchQueue.main.async {
                delegate.coldWalletIsAbleToAddFingerprint(able)
            }
        })
        
        if self.initialEnroll || self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func touchEnrollFingerprintBegin(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCTouchEnrollFpBegin(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidStartFingerprintEnrollment()
            }
        })
        
        if self.initialEnroll || self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func touchEnrollFingerprintEnd(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCTouchEnrollFpEnd(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            self.registered = true
            DispatchQueue.main.async {
                delegate.coldWalletDidFinishFingerprintEnrollment()
            }
        })
        
        if self.initialEnroll || self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func swipeEnrollFingerprintBegin(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCSwipeEnrollFpBegin(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidStartFingerprintEnrollment()
            }
        })
        
        if self.initialEnroll || self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func swipeEnrollFingerprintEnd(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCSwipeEnrollFpEnd(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            self.registered = true
            DispatchQueue.main.async {
                delegate.coldWalletDidFinishFingerprintEnrollment()
            }
        })
        
        if self.initialEnroll || self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func cancelEnrollFingerprint(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCCancelEnrollFp(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            self.registered = true
            DispatchQueue.main.async {
                delegate.coldWalletDidCancelFingerprintEnrollment()
            }
        })
        
        if self.initialEnroll || self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func getFingerprintEnrollmentState(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCQueryFpEnrollState(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let state = data as! ATCQueryFpEnrollState.State
            DispatchQueue.main.async {
                delegate.coldWalletDidUpdateFingerprintEnrollmentState(state.progress, state.placeFingerRequired)
            }
        })
        
        if self.initialEnroll || self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func loginWithFingerprintBegin(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        self.commandHandler.enqueueCommand(ATCLoginWithFpBegin(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidStartLoginWithFingerprint()
            }
        }))
    }
    
    public func loginWithFingerprintEnd(HDWIndex hdwIndex: UInt8, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let resultHandler: ATCommand.ResultHandler = { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let info = data as! ATCLoginWithFpEnd.Info
            self.loggedIn = info.loggedIn
            self.token = info.token
            self.hdwallet = nil
            self.loggedInHDWIndex = info.hdwIndex
            self.hdwInitState = info.masterNodeExistence
            
            if !self.loggedIn {
                DispatchQueue.main.async {
                    delegate.coldWalletDidFailToLogin()
                }
            }
            else if !info.masterNodeExistence[Int(info.hdwIndex)] {
                DispatchQueue.main.async {
                    delegate.coldWalletDidLogin(nil)
                }
            }
            else {
                self.hdwallet = ATHDWallet(Name: info.name, ColdWallet: self, HDWIndex: info.hdwIndex, ExistedWallets: info.existedAccountNumber)
                DispatchQueue.main.async {
                    delegate.coldWalletDidLogin(self.hdwallet)
                }
            }
        }
        
        if hdwIndex <= 1 {
            self.commandHandler.enqueueCommand(ATCLoginWithFpEnd(HDWIndex: hdwIndex, ResultHandler: resultHandler))
        }
        else {
            self.commandHandler.enqueueCommand(ATCLoginWithFpEnd(ResultHandler: resultHandler))
        }
    }
    
    public func loginWithFingerprintCancel(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        self.commandHandler.enqueueCommand(ATCLoginWithFpCancel(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidCancelLoginWithFingerprint()
            }
        }))
    }
    
    public func verifyFingerprintBegin(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        self.commandHandler.enqueueCommand(ATCVerifyFpBegin(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidStartFingerprintVerification()
            }
        }))
    }
    
    public func verifyFingerprintEnd(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        self.commandHandler.enqueueCommand(ATCVerifyFpEnd(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidFinishFingerprintVerification()
            }
        }))
    }

    public func getFingerprintVerificationState(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        self.commandHandler.enqueueCommand(ATCQueryFpVerifyState(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let state = data as! ATCQueryFpVerifyState.State
            DispatchQueue.main.async {
                delegate.coldWalletDidUpdateFingerprintVerificationState(state.verified ? state.matched : nil, state.placeFingerRequired)
            }
        }))
    }
    
    public func bindLoginFingerprintsBegin(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCBindFPForLoginBegin { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidStartBindingLoginFingerprints()
            }
        }
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func bindLoginFingerprintsEnd(Sequential sequential: Bool, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let resultHandler: ATCommand.ResultHandler = { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                if let bound = data as? Bool {
                    bound ? delegate.coldWalletDidBindLoginFingerprints() : delegate.coldWalletDidFailToBindLoginFingerprints()
                }
            }
        }
        
        let command = sequential ? ATCBindSequentialFPForLoginEnd(ResultHandler: resultHandler) : ATCBindFPForLoginEnd(ResultHandler: resultHandler)
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func verifyBoundFPBegin(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCVerifyBoundFPBegin { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidStartToVerifyBoundLoginFingerprints()
            }
        }
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func verifyBoundFPEnd(Sequential sequential: Bool, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let resultHandler: ATCommand.ResultHandler = { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                if let bound = data as? Bool {
                    bound ? delegate.coldWalletDidVerifyBoundLoginFingerprints() : delegate.coldWalletDidFailToVerifyBoundLoginFingerprints()
                }
            }
        }
        
        let command = sequential ? ATCVerifyBoundSequentialFPEnd(ResultHandler: resultHandler) : ATCVerifyBoundFPEnd(ResultHandler: resultHandler)
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func cancelBindingLoginFingerprints(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCCancelBindingLoginFP { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidCancelLoginFingerprints()
            }
        }
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func unbindLoginFingerprints(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCUnbindLoginFP { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidUnbindLoginFingerprints()
            }
        }
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func logout(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        self.commandHandler.enqueueCommand(ATCLogout(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidLogout()
                self.hdwallet = nil
                self.token = nil
                self.loggedIn = false
            }
        }))
    }
    
    public func initializeHDWallet(HDWIndex hdwIndex: UInt8, Mnemonic mnemonic: [String], Passphrase passphrase: String?, Name name: String, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        guard let seed = ATBIP39().deriveSeedFromMnemonic(Mnemonic: mnemonic, Passphrase: passphrase) else {
            DispatchQueue.main.async {
                delegate.coldWalletDidFailToInitializeHDWallet()
            }
            return
        }
        
        let command = ATCInitHDW(HDWIndex: hdwIndex, ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            if data as! Bool {
                let hdwallet = ATHDWallet(Name: name, ColdWallet: self, HDWIndex: hdwIndex, ExistedWallets: 0)
                if hdwIndex == 0 {
                    self.hdwallet = hdwallet
                }
                DispatchQueue.main.async {
                    delegate.coldWalletDidInitializeHDWallet(hdwallet)
                }
            }
            else {
                DispatchQueue.main.async {
                    delegate.coldWalletDidFailToInitializeHDWallet()
                }
            }
        })
        
        command.cmdData = seed
        if let utf8Name = name.data(using: .utf8) {
            command.cmdData?.append(utf8Name)
        }
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public struct HDWalletRecoveryInfo {
        let mnemonics: [String]
        let passphrase: String?
        let name: String
        public init(Mnemonics mnemonics: [String], Passphrase passphrase: String?, Name name: String) {
            self.mnemonics = mnemonics
            self.passphrase = passphrase
            self.name = name
        }
    }
    
    public struct CurrencyWalletRecoveryInfo : Equatable {
        public let purpose: UInt32?
        public let currency: ATCryptocurrencyType
        public let account: UInt32?
        public let timestamp: UInt32
        public let name: String
        public init(Purpose purpose: UInt32?, Currency currency: ATCryptocurrencyType, Account account: UInt32?, Timestamp timestamp: UInt32, Name name: String) {
            self.purpose = purpose
            self.currency = currency
            self.account = account
            self.timestamp = timestamp
            self.name = name
        }
    }
    
    public func recoverHDWallet(HDWIndex hdwIndex: UInt8, HDWalletRecoveryInfo hdwalletInfo: HDWalletRecoveryInfo, CurrencyWalletRecoveryInfo currencyWalletInfo: [CurrencyWalletRecoveryInfo], Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        guard let seed = ATBIP39().deriveSeedFromMnemonic(Mnemonic: hdwalletInfo.mnemonics, Passphrase: hdwalletInfo.passphrase) else {
            DispatchQueue.main.async {
                delegate.coldWalletDidFailToRecoverHDWallet()
            }
            return
        }
        ATLog.debug("Seed: \(seed as NSData)")
        
        var hdwallet: ATHDWallet? = nil
        let initHDWCommand = ATCInitHDW(HDWIndex: hdwIndex, ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            if data as! Bool {
                hdwallet = ATHDWallet(Name: hdwalletInfo.name, ColdWallet: self, HDWIndex: hdwIndex, ExistedWallets: 0)
                if hdwIndex == 0 {
                    self.hdwallet = hdwallet
                }
                if currencyWalletInfo.count == 0 {
                    DispatchQueue.main.async {
                        delegate.coldWalletDidRecoverHDWallet(hdwallet)
                    }
                }
            }
            else {
                DispatchQueue.main.async {
                    delegate.coldWalletDidFailToRecoverHDWallet()
                }
            }
        })
        
        initHDWCommand.cmdData = seed
        if let utf8Name = hdwalletInfo.name.data(using: .utf8) {
            initHDWCommand.cmdData?.append(utf8Name)
        }
        
        let bip44Purpose: UInt32 = 0x8000002C
        var commands: [ATCommand] = []
        var index = 0
        let lastIndex = currencyWalletInfo.count - 1
        currencyWalletInfo.forEach { (info) in
            let walletIndex = index
            var command: ATCommand!
            if let accountValue = info.account {
                command = ATCCreateSpecificAccount(ResultHandler: { (data, error) in
                    if error != nil {
                        ATLog.debug("Command Error: \(error!.description)")
                        switch error! {
                        case .failToConnect:
                            DispatchQueue.main.async {
                                delegate.coldWalletDidFailToConnect()
                            }
                        case .incorrectSW:
                            DispatchQueue.main.async {
                                delegate.coldWalletDidFailToRecoverHDWallet()
                            }
                        default:
                            DispatchQueue.main.async {
                                delegate.coldWalletDidFailToExecuteCommand(error!)
                            }
                        }
                        return
                    }
                    
                    let accountInfo = data as! ATCCreateSpecificAccount.Info
                    let wallet = ATCryptocurrencyWallet(ColdWallet: self, Purpose: info.purpose ?? bip44Purpose, CoinType: info.currency.coinType, Account: accountValue, AccountIndex: accountInfo.accountIndex, Name: info.name, Balance: ATUInt256(0), ExtKeys: 0, IntKeys: 0, CreationTime: info.timestamp, UniqueId: accountInfo.uniqueId, CurrencyType: info.currency.currencyType)
                    hdwallet?.numberOfWallet += 1
                    hdwallet?.wallets?.append(wallet)
                    if walletIndex == lastIndex {
                        DispatchQueue.main.async {
                            delegate.coldWalletDidRecoverHDWallet(hdwallet)
                        }
                    }
                })
            }
            else {
                command = ATCCreateAccount(ResultHandler: { (data, error) in
                    if error != nil {
                        ATLog.debug("Command Error: \(error!.description)")
                        switch error! {
                        case .failToConnect:
                            DispatchQueue.main.async {
                                delegate.coldWalletDidFailToConnect()
                            }
                        case .incorrectSW:
                            DispatchQueue.main.async {
                                delegate.coldWalletDidFailToRecoverHDWallet()
                            }
                        default:
                            DispatchQueue.main.async {
                                delegate.coldWalletDidFailToExecuteCommand(error!)
                            }
                        }
                        return
                    }
                    
                    let accountInfo = data as! ATCCreateAccount.Info
                    let wallet = ATCryptocurrencyWallet(ColdWallet: self, Purpose: info.purpose ?? bip44Purpose, CoinType: info.currency.coinType, Account: accountInfo.accountValue, AccountIndex: accountInfo.accountIndex, Name: info.name, Balance: ATUInt256(0), ExtKeys: 0, IntKeys: 0, CreationTime: info.timestamp, UniqueId: accountInfo.uniqueId, CurrencyType: info.currency.currencyType)
                    hdwallet?.numberOfWallet += 1
                    hdwallet?.wallets?.append(wallet)
                    if walletIndex == lastIndex {
                        DispatchQueue.main.async {
                            delegate.coldWalletDidRecoverHDWallet(hdwallet)
                        }
                    }
                })
            }
            
            
            var bPurpose = info.purpose?.bigEndian ?? bip44Purpose.bigEndian
            var bCoinType = info.currency.coinType.bigEndian
            var bAccount = info.account?.bigEndian ?? 0
            var bTimestamp = info.timestamp.bigEndian
            var bCurrencyType = info.currency.currencyType.bigEndian
            var curve = info.currency.curve
            command.cmdData = Data()
            command.cmdData?.append(UnsafeBufferPointer(start: &bPurpose, count: 1))
            command.cmdData?.append(UnsafeBufferPointer(start: &bCoinType, count: 1))
            (info.account != nil) ? command.cmdData?.append(UnsafeBufferPointer(start: &bAccount, count: 1)) : nil
            command.cmdData?.append(UnsafeBufferPointer(start: &bTimestamp, count: 1))
            command.cmdData?.append(UnsafeBufferPointer(start: &bCurrencyType, count: 1))
            command.cmdData?.append(UnsafeBufferPointer(start: &curve, count: 1))
            if let utf8Name = info.name.data(using: String.Encoding.utf8) {
                command.cmdData?.append(utf8Name)
            }
            commands.append(command)
            index += 1
        }
        
        if self.loggedIn || !initHDWCommand.loginRequired {
            let commandBundle = ATCommandBundle()
            _ = commandBundle.appendCommand(initHDWCommand)
            commands.forEach({ (command) in
                _ = commandBundle.appendCommand(command)
            })
            self.commandHandler.enqueueCommandBundle(commandBundle)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            let commandBundle = ATCommandBundle()
            _ = commandBundle.appendCommand(loginCmd)
            _ = commandBundle.appendCommand(initHDWCommand)
            commands.forEach({ (command) in
                _ = commandBundle.appendCommand(command)
            })
            self.commandHandler.enqueueCommandBundle(commandBundle)
        }
    }
    
    public func factoryReset(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCFactoryReset { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidFactoryReset()
            }
        }
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func resetHDWallet(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCResetHDW { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidResetHDWallets()
            }
        }
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    func createWallet(Purpose purpose: UInt32, Currency currency: ATCryptocurrencyType, Account account: UInt32?, CreationTime timestamp: UInt32, Name name: String, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        
        var command: ATCommand!
        if let accountValue = account {
            command = ATCCreateSpecificAccount(ResultHandler: { (data, error) in
                if error != nil {
                    ATLog.debug("Command Error: \(error!.description)")
                    switch error! {
                    case .failToConnect:
                        DispatchQueue.main.async {
                            delegate.coldWalletDidFailToConnect()
                        }
                    case .incorrectSW:
                        DispatchQueue.main.async {
                            delegate.coldWalletDidFailToCreateWallet()
                        }
                    default:
                        DispatchQueue.main.async {
                            delegate.coldWalletDidFailToExecuteCommand(error!)
                        }
                    }
                    return
                }
                
                let info = data as! ATCCreateSpecificAccount.Info
                let wallet = ATCryptocurrencyWallet(ColdWallet: self, Purpose: purpose, CoinType: currency.coinType, Account: accountValue, AccountIndex: info.accountIndex, Name: name, Balance: ATUInt256(0), ExtKeys: 0, IntKeys: 0, CreationTime: timestamp, UniqueId: info.uniqueId, CurrencyType: currency.currencyType)
                DispatchQueue.main.async {
                    delegate.coldWalletDidCreateWallet(wallet)
                }
            })
        }
        else {
            command = ATCCreateAccount(ResultHandler: { (data, error) in
                if error != nil {
                    ATLog.debug("Command Error: \(error!.description)")
                    switch error! {
                    case .failToConnect:
                        DispatchQueue.main.async {
                            delegate.coldWalletDidFailToConnect()
                        }
                    case .incorrectSW:
                        DispatchQueue.main.async {
                            delegate.coldWalletDidFailToCreateWallet()
                        }
                    default:
                        DispatchQueue.main.async {
                            delegate.coldWalletDidFailToExecuteCommand(error!)
                        }
                    }
                    return
                }
                
                let info = data as! ATCCreateAccount.Info
                let wallet = ATCryptocurrencyWallet(ColdWallet: self, Purpose: purpose, CoinType: currency.coinType, Account: info.accountValue, AccountIndex: info.accountIndex, Name: name, Balance: ATUInt256(0), ExtKeys: 0, IntKeys: 0, CreationTime: timestamp, UniqueId: info.uniqueId, CurrencyType: currency.currencyType)
                DispatchQueue.main.async {
                    delegate.coldWalletDidCreateWallet(wallet)
                }
            })
        }
        
        var bPurpose = purpose.bigEndian
        var bCoinType = currency.coinType.bigEndian
        var bAccount = account?.bigEndian ?? 0
        var bTimestamp = timestamp.bigEndian
        var bCurrencyType = currency.currencyType.bigEndian
        var curve = currency.curve
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bPurpose, count: 1))
        command.cmdData?.append(UnsafeBufferPointer(start: &bCoinType, count: 1))
        (account != nil) ? command.cmdData?.append(UnsafeBufferPointer(start: &bAccount, count: 1)) : nil
        command.cmdData?.append(UnsafeBufferPointer(start: &bTimestamp, count: 1))
        command.cmdData?.append(UnsafeBufferPointer(start: &bCurrencyType, count: 1))
        command.cmdData?.append(UnsafeBufferPointer(start: &curve, count: 1))
        if let utf8Name = name.data(using: String.Encoding.utf8) {
            command.cmdData?.append(utf8Name)
        }
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    func removeWallet(AccountIndex index: UInt32, UniqueId uid: [UInt8], Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCRemoveAccount(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                case .incorrectSW:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToRemoveWallet()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidRemoveWallet()
            }
        })
        
        var bAccountIndex = index.bigEndian
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bAccountIndex, count: 1))
        command.cmdData?.append(contentsOf: uid)
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    func getWalletInfo(AccountIndex index: UInt32, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCQueryAccountInfo(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let info = data as! ATCQueryAccountInfo.Info
            DispatchQueue.main.async {
                delegate.coldWalletDidGetWalletInfo(info.purpose, info.coinType, info.account, info.balance, info.name, info.numberOfExtKey, info.numberOfIntKey, info.timestamp, info.uniqueId, info.currencyType)
            }
        })
        
        var bAccountIndex = index.bigEndian
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bAccountIndex, count: 1))
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    func getWalletExternalKeyInfo(AccountIndex accountIndex: UInt32, KeyId keyId: UInt32, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCQueryAccountExtKeyInfo(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let key = data as! [UInt8]
            DispatchQueue.main.async {
                delegate.coldWalletDidGetWalletExternalKeyInfo(key)
            }
        })
        
        var bAccountIndex = accountIndex.bigEndian
        var bKeyId = keyId.bigEndian
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bAccountIndex, count: 1))
        command.cmdData?.append(UnsafeBufferPointer(start: &bKeyId, count: 1))
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }

    func getWalletInternalKeyInfo(AccountIndex accountIndex: UInt32, KeyId keyId: UInt32, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCQueryAccountIntKeyInfo(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let key = data as! [UInt8]
            DispatchQueue.main.async {
                delegate.coldWalletDidGetWalletInternalKeyInfo(key)
            }
        })
        
        var bAccountIndex = accountIndex.bigEndian
        var bKeyId = keyId.bigEndian
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bAccountIndex, count: 1))
        command.cmdData?.append(UnsafeBufferPointer(start: &bKeyId, count: 1))
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }

    func prepareToSignDataWithFpVerification(AccountIndex accountIndex: UInt32, Transaction transaction: ATCryptocurrencyTransaction, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCPrepareToSignDataWithFpVerification { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidPrepareToSignData()
            }
        }
        
        guard let unsignedDataInfos = transaction.unsignedTransactionDataInfos else {
            DispatchQueue.main.async {
                delegate.coldWalletDidFailToExecuteCommand(.invalidParameter)
            }
            return
        }
        var bAccountIndex = accountIndex.bigEndian
        var bDataCount = UInt16(unsignedDataInfos.count).bigEndian
        var addressArray = [UInt8](transaction.address.utf8)
        if addressArray.count > 48 {
            ATLog.debug("Address length is over 48")
            let subStr = String(transaction.address.prefix(48))
            addressArray = [UInt8](subStr.utf8)
        }
        guard addressArray.count <= 48 else {
            ATLog.error("Address length(\(addressArray.count)) is too long. Address: \(transaction.address)")
            DispatchQueue.main.async {
                delegate.coldWalletDidFailToExecuteCommand(.invalidParameter)
            }
            return
        }
        if addressArray.count < 48 {
            let start = addressArray.count
            for _ in start..<48 {
                addressArray.append(0)
            }
        }
        var tmpData = Data()
        unsignedDataInfos.forEach { (info) in
            var bKeyId = info.keyId.bigEndian
            var bChainId = info.chainId.bigEndian
            tmpData.append(UnsafeBufferPointer(start: &bChainId, count: 1))
            tmpData.append(UnsafeBufferPointer(start: &bKeyId, count: 1))
            tmpData.append(contentsOf: info.data.bytes)
        }
        
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bAccountIndex, count: 1))
        command.cmdData?.append(contentsOf: transaction.totalAmount.bytes.reversed())
        command.cmdData?.append(contentsOf: addressArray)
        command.cmdData?.append(UnsafeBufferPointer(start: &bDataCount, count: 1))
        command.cmdData?.append(tmpData)
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    func signDataWithFpVerificationResult(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCStartToSignData(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                DispatchQueue.main.async {
                    delegate.coldWalletDidFailToExecuteCommand(error!)
                }
                return
            }
            
            let signatures = data as! [Data]
            DispatchQueue.main.async {
                delegate.coldWalletDidSignData(signatures)
            }
        })
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else {
            DispatchQueue.main.async {
                delegate.coldWalletDidFailToExecuteCommand(.commandError)
            }
        }
    }
    
    func cancelToSignData() {
        ATLog.debug("\(#function)")
        let command = ATCCancelToSignData(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
            }
        })
        self.commandHandler.enqueueCommand(command)
    }
    
    func updateWalletBalance(AccountIndex accountIndex: UInt32, Balance balance: ATUInt256, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCSetAccountBalance { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidUpdateWalletBalance()
            }
        }

        var bAccountIndex = accountIndex.bigEndian
        
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bAccountIndex, count: 1))
        command.cmdData?.append(contentsOf: balance.bytes.reversed())
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    func updateWalletExternalKeyIndex(AccountIndex accountIndex: UInt32, KeyId keyId: UInt32, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCSetAccountExternalKeyIndex { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidUpdateWalletExternalKeyIndex()
            }
        }
        
        var bAccountIndex = accountIndex.bigEndian
        var bKeyId = keyId.bigEndian
        
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bAccountIndex, count: 1))
        command.cmdData?.append(UnsafeBufferPointer(start: &bKeyId, count: 1))

        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    func updateWalletInternalKeyIndex(AccountIndex accountIndex: UInt32, KeyId keyId: UInt32, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCSetAccountInternalKeyIndex { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidUpdateWalletInternalKeyIndex()
            }
        }
        
        var bAccountIndex = accountIndex.bigEndian
        var bKeyId = keyId.bigEndian
        
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bAccountIndex, count: 1))
        command.cmdData?.append(UnsafeBufferPointer(start: &bKeyId, count: 1))
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    func getHDWalletExtendedPublicKeyInfo(Path path: [UInt32], Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCQueryExtendedPublicKeyInfo(ResultHandler: { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            let info = data as! ATCQueryExtendedPublicKeyInfo.Info
            DispatchQueue.main.async {
                delegate.coldWalletDidGetHDWalletExtendedPublicKeyInfo(info.key, info.chainCode, info.fingerprint)
            }
        })
        
        command.cmdData = Data()
        path.forEach { (level) in
            var bigEndian = level.bigEndian
            command.cmdData?.append(UnsafeBufferPointer(start: &bigEndian, count: 1))
        }
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func setLanguage(Language language: Language, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCSetLanguage { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidSetLanguage()
            }
        }
        
        command.cmdData = Data()
        command.cmdData?.append(language.id)
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func startFirmwareOTA(Type type: FirmwareType, Data data: Data?, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCStartFirmwareOTA { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidStartFirmwareOTA()
            }
        }
        
        command.cmdData = Data()
        command.cmdData?.append(type.rawValue)
        (data != nil) ? command.cmdData?.append(data!) : nil
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func sendFirmwareData(Data data: Data?, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCSendFirmwareData { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidSendFirmwareData()
            }
        }
        
        command.cmdData = data
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func finishFirmwareOTA(Data data: Data?, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCFinishFirmwareOTA { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidFinishFirmwareOTA()
            }
        }
        
        command.cmdData = data
        
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func cancelFirmwareOTA(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCCancelFirmwareOTA { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidCancelFirmwareOTA()
            }
        }
                
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func calibrateFingerprintSensor(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCCalibrateFingerprintSensor { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidCalibrateFingerprintSensor()
            }
        }
                
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func startFingerprintDeletion(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCDeleteFpBegin { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidStartFingerprintDeletion()
            }
        }
                
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func finishFingerprintDeletion(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCDeleteFpEnd { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidFinishFingerprintDeletion(data as? [UInt32])
            }
        }
                
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func cancelFingerprintDeletion(Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCDeleteFpCancel { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                delegate.coldWalletDidCancelFingerprintDeletion()
            }
        }
                
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
    
    public func changeHDWalletName(Name name: String, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCSetHDWName { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            self.hdwallet?.name = name
            DispatchQueue.main.async {
                delegate.coldWalletDidChangeHDWalletName()
            }
        }
        
        command.cmdData = name.data(using: .utf8)
                
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }
        
    public func changeWalletName(AccountIndex accountIndex: UInt32, Name name: String, Delegate delegate: ATColdWalletDelegate) {
        ATLog.debug("\(#function)")
        let command = ATCSetAccountName { (data, error) in
            if error != nil {
                ATLog.debug("Command Error: \(error!.description)")
                switch error! {
                case .failToConnect:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToConnect()
                    }
                default:
                    DispatchQueue.main.async {
                        delegate.coldWalletDidFailToExecuteCommand(error!)
                    }
                }
                return
            }
            
            if let wallets = self.hdwallet?.wallets, wallets.count > accountIndex {
                wallets[Int(accountIndex)].name = name
            }
            DispatchQueue.main.async {
                delegate.coldWalletDidChangeWalletName(accountIndex)
            }
        }
        
        var bAccountIndex = accountIndex.bigEndian
        
        command.cmdData = Data()
        command.cmdData?.append(UnsafeBufferPointer(start: &bAccountIndex, count: 1))
        command.cmdData?.append(name.data(using: .utf8) ?? Data())
                
        if self.loggedIn || !command.loginRequired {
            self.commandHandler.enqueueCommand(command)
        }
        else if self.token == nil {
            DispatchQueue.main.async {
                delegate.coldWalletNeedsLoginWithFingerprint()
            }
        }
        else {
            let loginCmd = genTokenLoginCmd(Delegate: delegate)
            self.commandHandler.enqueueCommandBundle(ATCommandBundle().appendCommand(loginCmd).appendCommand(command))
        }
    }


}
