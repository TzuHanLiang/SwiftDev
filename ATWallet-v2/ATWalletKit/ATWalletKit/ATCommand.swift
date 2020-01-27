//
//  ATCommand.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/8.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

class ATCommand : NSObject {

    internal var succeeded: Bool = false
    internal var cmdPrefix: [UInt8] = [0, 0, 0, 0, 0, 0, 0] // [CLA, INS, P1, P2, LC0, LC1, LC2]
    var cmdData: Data?
    internal var cmdSuffix: [UInt8] = [0, 0] // [LE0, LE1]
    internal var loginRequired: Bool = true
    
    var data: Data {
        get {
            var data = Data()
            if let cmdDataLength = self.cmdData?.count {
                cmdPrefix[6] = UInt8(cmdDataLength & 0xFF)
                cmdPrefix[5] = UInt8((cmdDataLength >> 8) & 0xFF)
                cmdPrefix[4] = UInt8((cmdDataLength >> 16) & 0xFF)
                data.append(self.cmdData!)
            }
            data.insert(contentsOf: self.cmdPrefix, at: 0)
            data.append(contentsOf: self.cmdSuffix)
            return data
        }
    }
    
    typealias ResultHandler = (_ data: AnyObject?, _ error: ATError?) -> ()
    var resultHandler: ResultHandler
    
    init(ResultHandler handler: @escaping ResultHandler) {
        self.resultHandler = handler
    }
    
    func checkSW(_ response: Data) -> Bool {
        let sw = response.subdata(in: (response.count - 2)..<(response.count)).withUnsafeBytes({ (pointer) -> UInt16 in
            return CFSwapInt16BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee)
        })
        return (sw == 0x9000) ? true : false
    }
    
    func handleResponse(_ response: Data) {}
}

/* ATCQueryVersionInfo
 * ResultHandler(Info?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW .incorrectResponse
 */
class ATCQueryVersionInfo : ATCommand {
    
    struct Info {
        let fwVersion: Data
        let seVersion: Data
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x00, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let fwVersionLength = Int(response.first!)
        guard response.count > (1 + fwVersionLength) else {
            self.succeeded = false
            self.resultHandler(nil, .incorrectResponse)
            return
        }
        let fwVersion = response.subdata(in: 1..<(1 + fwVersionLength))
        
        let seVersionLength = Int(response.subdata(in: (1 + fwVersionLength)..<(1 + fwVersionLength + 1)).first!)
        guard response.count >= (1 + fwVersionLength + 1 + seVersionLength) else {
            self.succeeded = false
            self.resultHandler(nil, .incorrectResponse)
            return
        }
        let seVersion = response.subdata(in: (1 + fwVersionLength + 1)..<(1 + fwVersionLength + 1 + Int(seVersionLength)))
        
        let info = Info(fwVersion: fwVersion, seVersion: seVersion)
        self.succeeded = true
        self.resultHandler(info as AnyObject?, nil)
    }
}

/* ATCQueryDeviceInfo
 * ResultHandler(Info?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW .incorrectResponse
 */
class ATCQueryDeviceInfo : ATCommand {
    
    struct Info {
        let deviceName: String
        let batteryCharging: Bool
        let batteryLevel: UInt
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x00, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let length = Int(response.first!)
        guard response.count > (1 + length) else {
            self.succeeded = false
            self.resultHandler(nil, .incorrectResponse)
            return
        }
        let deviceName = String(data: response.subdata(in: 1..<(1 + length)), encoding: .utf8)
        let batteryState = UInt8(response.subdata(in: (1 + length)..<(1 + length + 1)).first!)
        let charging = (batteryState & 0x80) > 0
        let batteryLevel = ((batteryState & 0x7F) > 100) ? 100 : (batteryState & 0x7F)
        
        let info = Info(deviceName: deviceName ?? "unknown", batteryCharging: charging, batteryLevel: UInt(batteryLevel))
        self.succeeded = true
        self.resultHandler(info as AnyObject?, nil)
    }
}

/* ATCQueryEnrolledFp
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCQueryEnrolledFp : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x01, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        let enrolled = (byte == 0) ? false : true
        self.succeeded = true
        self.resultHandler(enrolled as AnyObject?, nil)
    }
}

/* ATCQueryAllowFpEnroll
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCQueryAllowFpEnroll : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x02, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        let allowed = (byte == 0) ? false : true
        self.succeeded = true
        self.resultHandler(allowed as AnyObject?, nil)
    }
}

/* ATCTouchEnrollFpBegin
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCTouchEnrollFpBegin : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x03, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCTouchEnrollFpEnd
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCTouchEnrollFpEnd : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x03, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCSwipeEnrollFpBegin
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCSwipeEnrollFpBegin : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x03, 0x02, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCSwipeEnrollFpEnd
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCSwipeEnrollFpEnd : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x03, 0x03, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCCancelEnrollFp
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCCancelEnrollFp : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x03, 0x04, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCQueryFpEnrollState
 * ResultHandler(ATCQueryFpEnrollState.State?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW .commandError
 */
class ATCQueryFpEnrollState : ATCommand {
    
    struct State {
        let progress: UInt8 // 0 - 100
        let placeFingerRequired: Bool
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x04, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        if byte == 0xFF {
            self.succeeded = false
            self.resultHandler(nil, .commandError)
            return
        }
        let placeFingerRequired = ((byte & 0x80) == 0) ? true : false
        let progress = ((byte & 0x7F) > 100) ? 100 : (byte & 0x7F)
        let state = State(progress: progress, placeFingerRequired: placeFingerRequired)
        self.succeeded = true
        self.resultHandler(state as AnyObject?, nil)
    }
}

/* ATCLoginWithToken
 * ResultHandler(Info?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCLoginWithToken : ATCommand {
    
    struct Info {
        let loggedIn: Bool
        let masterNodeExistence: [Bool]
        let hdwIndex: UInt8
        let existedAccountNumber: UInt32
        let name: String?
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x05, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        // | State (1 byte) | Existed account number (4 bytes) | Name (32 bytes) |
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        let loggedIn = (byte == 0xFF) ? false : true
        guard loggedIn else {
            let info = Info(loggedIn: loggedIn, masterNodeExistence: [], hdwIndex: 0xFF, existedAccountNumber: 0, name: nil)
            self.succeeded = true
            self.resultHandler(info as AnyObject?, nil)
            return
        }
        
        let masterNodeExistence: [Bool] = [(byte & 0x80) > 0, (byte & 0x40) > 0]
        let hdwIndex: UInt8 = byte & 0x01
        let existedAccountNumber = response.subdata(in: 1..<5).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        var name: String? = nil
        if loggedIn && masterNodeExistence[Int(hdwIndex)] {
            name = String(bytes: response.subdata(in: 5..<37), encoding: String.Encoding.utf8)?.trimmingCharacters(in: .newlines).trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .illegalCharacters)
        }
        let info = Info(loggedIn: loggedIn, masterNodeExistence: masterNodeExistence, hdwIndex: hdwIndex, existedAccountNumber: existedAccountNumber, name: name)
        self.succeeded = true
        self.resultHandler(info as AnyObject?, nil)
    }
}

/* ATCLoginWithFpBegin
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCLoginWithFpBegin : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x06, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCLoginWithFpEnd
 * ResultHandler(Info?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCLoginWithFpEnd : ATCommand {
    
    struct Info {
        let loggedIn: Bool
        let masterNodeExistence: [Bool]
        let hdwIndex: UInt8
        let existedAccountNumber: UInt32
        let name: String?
        let token: Data?
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x06, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    init(HDWIndex hdwIndex: UInt8, ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x06, hdwIndex + 2, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        // | State (1 byte) | Existed account number (4 bytes) | Name (32 bytes) | Token (dynamic length) |
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        let loggedIn = (byte == 0xFF) ? false : true
        guard loggedIn else {
            let info = Info(loggedIn: loggedIn, masterNodeExistence: [], hdwIndex: 0xFF, existedAccountNumber: 0, name: nil, token: nil)
            self.succeeded = true
            self.resultHandler(info as AnyObject?, nil)
            return
        }
        
        let masterNodeExistence: [Bool] = [(byte & 0x80) > 0, (byte & 0x40) > 0]
        let hdwIndex: UInt8 = byte & 0x01
        let existedAccountNumber = response.subdata(in: 1..<5).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        var name: String? = nil
        if loggedIn && masterNodeExistence[Int(hdwIndex)] {
            name = String(bytes: response.subdata(in: 5..<37), encoding: String.Encoding.utf8)?.trimmingCharacters(in: .newlines).trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .illegalCharacters)
        }
        let token = response.subdata(in: 37..<(response.count - 2))
        let info = Info(loggedIn: loggedIn, masterNodeExistence: masterNodeExistence, hdwIndex: hdwIndex, existedAccountNumber: existedAccountNumber, name: name, token: token)
        self.succeeded = true
        self.resultHandler(info as AnyObject?, nil)
    }
}

/* ATCLoginWithFpCancel
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCLoginWithFpCancel : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x06, 0x04, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCVerifyFpBegin
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCVerifyFpBegin : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x07, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCVerifyFpEnd
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCVerifyFpEnd : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x07, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCQueryFpVerifyState
 * ResultHandler(ATCQueryFpVerifyState.State?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW .commandError
 */
class ATCQueryFpVerifyState : ATCommand {
    
    struct State {
        let verified: Bool
        let matched: Bool
        let placeFingerRequired: Bool
        let fpid: UInt32
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x08, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        if byte == 0xFF {
            self.succeeded = false
            self.resultHandler(nil, .commandError)
            return
        }
        
        let placeFingerRequired = ((byte & 0x80) == 0) ? true : false
        let verified = ((byte & 0x40) > 0) ? true : false
        let matched = ((byte & 0x20) > 0) ? true : false
        var fpid: UInt32 = 0
        if matched {
            fpid = response.subdata(in: 1..<5).withUnsafeBytes({ (pointer) -> UInt32 in
                return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
            })
        }
        let state = State(verified: verified, matched: matched, placeFingerRequired: placeFingerRequired, fpid: fpid)
        self.succeeded = true
        self.resultHandler(state as AnyObject?, nil)
    }
}

/* ATCBindFPForLoginBegin
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCBindFPForLoginBegin : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x09, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCBindFPForLoginEnd
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCBindFPForLoginEnd : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x09, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        
        self.succeeded = byte > 0 && byte < 0xFF
        self.resultHandler(self.succeeded as AnyObject?, nil)
    }
}

/* ATCBindSequentialFPForLoginEnd
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCBindSequentialFPForLoginEnd : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x09, 0x02, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        
        self.succeeded = byte > 0 && byte < 0xFF
        self.resultHandler(self.succeeded as AnyObject?, nil)
    }
}

/* ATCVerifyBoundFPBegin
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCVerifyBoundFPBegin : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x09, 0x03, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCVerifyBoundFPEnd
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCVerifyBoundFPEnd : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x09, 0x04, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        
        self.succeeded = byte > 0 && byte < 0xFF
        self.resultHandler(self.succeeded as AnyObject?, nil)
    }
}

/* ATCVerifyBoundSequentialFPEnd
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCVerifyBoundSequentialFPEnd : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x09, 0x05, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        let byte = response.withUnsafeBytes({ (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        })
        
        self.succeeded = byte > 0 && byte < 0xFF
        self.resultHandler(self.succeeded as AnyObject?, nil)
    }
}

/* ATCCancelBindingLoginFP
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCCancelBindingLoginFP : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x09, 0x06, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCUnbindLoginFP
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCUnbindLoginFP : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x09, 0x07, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCLogout
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCLogout : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x0A, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}


/* ATCInitHDW
 * cmdData includes 64 bytes seed and up to 32 bytes name
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCInitHDW : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x0B, 0, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    init(HDWIndex hdwIndex: UInt8, ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x0B, hdwIndex, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCCreateAccount
 * cmdData includes 4 bytes purpos, 4 bytes coin type, 4 bytes timestamp, 4 bytes currency type, 1 byte curve type and up to 32 bytes name
 * ResultHandler(Info?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCCreateAccount : ATCommand {
    
    struct Info {
        let accountIndex: UInt32
        let uniqueId: [UInt8]
        let accountValue: UInt32
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x0C, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        // | account index (4 bytes) | Unique ID (16 bytes) | Account Value (4 bytes) |
        let accountIndex = response.subdata(in: 0..<4).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let uniqueId = [UInt8](response.subdata(in: 4..<20))
        let accountValue = response.subdata(in: 20..<24).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let info = Info(accountIndex: accountIndex, uniqueId: uniqueId, accountValue: accountValue)
        self.succeeded = true
        self.resultHandler(info as AnyObject?, nil)
    }
}

/* ATCCreateSpecificAccount
 * cmdData includes 4 bytes purpose, 4 bytes coin type, 4 bytes account value, 4 bytes timestamp, 4 bytes currency type, 1 byte curve type and up to 32 bytes name
 * ResultHandler(Info?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCCreateSpecificAccount : ATCommand {
    
    struct Info {
        let accountIndex: UInt32
        let uniqueId: [UInt8]
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x0C, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        // | account index (4 bytes) | Unique ID (16 bytes) |
        let accountIndex = response.subdata(in: 0..<4).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let uniqueId = [UInt8](response.subdata(in: 4..<20))
        let info = Info(accountIndex: accountIndex, uniqueId: uniqueId)
        self.succeeded = true
        self.resultHandler(info as AnyObject?, nil)
    }
}

/* ATCRemoveAccount
 * cmdData is 4 bytes account index, 16 bytes unique id
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCRemoveAccount : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x0D, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCQueryAccountInfo
 * cmdData is 4 bytes account index
 * ResultHandler(Info?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCQueryAccountInfo : ATCommand {
    
    struct Info {
        let purpose: UInt32
        let coinType: UInt32
        let account: UInt32
        let balance: ATUInt256
        let name: String
        let numberOfExtKey: UInt32
        let numberOfIntKey: UInt32
        let timestamp: UInt32
        let uniqueId: [UInt8]
        let currencyType: UInt32
        let curveType: UInt8
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x0E, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        // | Purpose (4 bytes) | Coin Type (4 bytes) | Balance (32 bytes) | Name (32 bytes) | Number of External Key (4 bytes) | Number of Internal Key (4 bytes) | Creation Time (4 bytes) | Unique ID (16 bytes) | Currency Type (4 bytes) | Curve Type (1 byte) | Account (4 bytes) |
        let purpose = response.subdata(in: 0..<4).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let coinType = response.subdata(in: 4..<8).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let balance = ATUInt256([UInt8](response.subdata(in: 8..<40)).reversed() as [UInt8])
        let name = String(data: response.subdata(in: 40..<72), encoding: String.Encoding.utf8)?.trimmingCharacters(in: .newlines).trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .illegalCharacters) ?? NSLocalizedString("no_name", comment: "")
        let numberOfExtKey = response.subdata(in: 72..<76).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let numberOfIntKey = response.subdata(in: 76..<80).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let timestamp = response.subdata(in: 80..<84).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let uniqueId = [UInt8](response.subdata(in: 84..<100))
        let currencyType = response.subdata(in: 100..<104).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)  & 0x7FFFFFFF // remove hardened bit
        })
        let curveType = response[104]
        let account = response.subdata(in: 105..<109).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let info = Info(purpose: purpose, coinType: coinType, account: account, balance: balance, name: name, numberOfExtKey: numberOfExtKey, numberOfIntKey: numberOfIntKey, timestamp: timestamp, uniqueId: uniqueId, currencyType: currencyType, curveType: curveType)
        self.succeeded = true
        self.resultHandler(info as AnyObject?, nil)
    }
}

/* ATCQueryAccountExtKeyInfo
 * cmdData includes 4 bytes account index and 4 bytes key id
 * ResultHandler([UInt8]?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCQueryAccountExtKeyInfo : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x0F, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        // | Public Key (64 bytes) |
        let key = [UInt8](response.subdata(in: 0..<64))
        self.succeeded = true
        self.resultHandler(key as AnyObject?, nil)
    }
}

/* ATCQueryAccountIntKeyInfo
 * cmdData includes 4 bytes account index and 4 bytes key id
 * ResultHandler([UInt8]?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCQueryAccountIntKeyInfo : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x0F, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        // | Public Key (64 bytes) |
        let key = [UInt8](response.subdata(in: 0..<64))
        self.succeeded = true
        self.resultHandler(key as AnyObject?, nil)
    }
}

/* ATCPrepareToSignDataWithFpVerification
 * cmdData includes 4 bytes account index, 32 bytes balance, 48 bytes address, 2 bytes number of signing data structure and [ 4 bytes key chain id, 4 bytes key id, 32 bytes data]
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCPrepareToSignDataWithFpVerification : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x10, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCStartToSignData
 * ResultHandler([Data]?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW .incorrectResponse
 */
class ATCStartToSignData : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x10, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        // | Number of Signature (2 bytes) | Signatures (65 bytes each) |
        let responseArray = [UInt8](response)
        let count = Int(responseArray[0] << 8) | Int(responseArray[1])
        guard response.count == (2 + count * 65 + 2) else {
            self.succeeded = false
            self.resultHandler(nil, .incorrectResponse)
            return
        }
        
        var rsvSignatures: [Data] = []
        for i in 0..<count {
            let signature = response.subdata(in: (2 + 65 * i)..<(2 + 65 * (i + 1)))
            rsvSignatures.append(signature)
        }
        
        self.succeeded = true
        self.resultHandler(rsvSignatures as AnyObject?, nil)
    }
}

/* ATCCancelToSignData
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCCancelToSignData : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x10, 0x02, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCSetAccountBalance
 * cmdData includes 4 bytes account index and 32 bytes balance
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCSetAccountBalance : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x11, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCSetAccountExternalKeyIndex
 * cmdData includes 4 bytes account index and 4 bytes key id
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCSetAccountExternalKeyIndex : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x12, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCSetAccountInternalKeyIndex
 * cmdData includes 4 bytes account index and 4 bytes key id
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCSetAccountInternalKeyIndex : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x12, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCFactoryReset
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCFactoryReset : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x13, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCResetHDW
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCResetHDW : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x13, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCQueryExtendedPublicKey
 * cmdData includes 4 bytes purpose or/and 4 bytes coin type or/and 4 bytes account or/and 4 bytes change or/and 4 bytes index
 * ResultHandler(Info?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCQueryExtendedPublicKeyInfo : ATCommand {
    
    struct Info {
        let key: [UInt8]
        let chainCode: [UInt8]
        let fingerprint: UInt32
    }
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x14, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        guard response.count >= (64 + 32 + 2) else {
            self.succeeded = false
            self.resultHandler(nil, .incorrectResponse)
            return
        }
        
        // | Extended Public Key (64 bytes) | Chain Code (32 bytes) | Fingerprint of Parent Key (4 bytes) |
        let key = [UInt8](response.subdata(in: 0..<64))
        let chainCode = [UInt8](response.subdata(in: 64..<96))
        let fingerprint = response.subdata(in: 96..<100).withUnsafeBytes({ (pointer) -> UInt32 in
            return CFSwapInt32BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee)
        })
        let info = Info(key: key, chainCode: chainCode, fingerprint: fingerprint)
        self.succeeded = true
        self.resultHandler(info as AnyObject?, nil)
    }
}

/* ATCSetLanguage
 * cmdData includes 1 byte language id
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCSetLanguage : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x15, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}


/* ATCStartFirmwareOTA
 * cmdData includes 1 byte firmware id, N bytes data
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCStartFirmwareOTA : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x16, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = true
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCSendFirmwareData
 * cmdData includes N bytes data
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCSendFirmwareData : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x16, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = true
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCFinishFirmwareOTA
 * cmdData includes nothing or N bytes data
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCFinishFirmwareOTA : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x16, 0x02, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = true
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCCancelFirmwareOTA
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCCancelFirmwareOTA : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x16, 0x03, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = true
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCCalibrateFingerprintSensor
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCCalibrateFingerprintSensor : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x17, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = false
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCDeleteFpBegin
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCDeleteFpBegin : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x18, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = true
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCDeleteFpEnd
 * ResultHandler([UInt32]?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCDeleteFpEnd : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x18, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = true
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        guard let numberOfFpid = response.first, numberOfFpid != 0xFF, response.count >= (numberOfFpid * 4 + 1 + 2) else {
            self.succeeded = false
            self.resultHandler(nil, .commandError)
            return
        }
        
        let bytes = [UInt8](response)
        var fpids: [UInt32] = []
        if numberOfFpid > 0 {
            for index in 0..<Int(numberOfFpid) {
                var fpid: UInt32 = 0;
                fpid |= (UInt32(bytes[1 + (index * 4)]) << 24)
                fpid |= (UInt32(bytes[1 + (index * 4) + 1]) << 16)
                fpid |= (UInt32(bytes[1 + (index * 4) + 2]) << 8)
                fpid |= UInt32(bytes[1 + (index * 4) + 3])
                fpids.append(fpid)
            }
        }
        
        self.succeeded = true
        self.resultHandler(fpids as AnyObject?, nil)
    }
}

/* ATCDeleteFpCancel
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCDeleteFpCancel : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x18, 0x02, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = true
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCSetHDWName
 * cmdData includes up to 32 bytes name
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCSetHDWName : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x19, 0x00, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = true
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}

/* ATCSetAccountName
 * cmdData includes 4 bytes account index, up to 32 bytes name
 * ResultHandler(Bool?, ATError?)
 * ATError: .failToConnect .failToEncode .failToDecode .overlength .failToSend .failToReceive .incorrectSW
 */
class ATCSetAccountName : ATCommand {
    
    override init(ResultHandler handler: @escaping ResultHandler) {
        super.init(ResultHandler: handler)
        self.cmdPrefix = [0x00, 0x77, 0x19, 0x01, 0x00, 0x00, 0x00]
        self.cmdData = nil
        self.cmdSuffix = [0x00, 0x00]
        self.loginRequired = true
    }
    
    override func handleResponse(_ response: Data) {
        if !checkSW(response) {
            self.succeeded = false
            self.resultHandler(nil, .incorrectSW)
            return
        }
        
        self.succeeded = true
        self.resultHandler(true as AnyObject?, nil)
    }
}
