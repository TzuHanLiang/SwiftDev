//
//  ATCryptocurrencyTransaction.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/1/10.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Foundation


public class ATCryptocurrencyTransaction: NSObject {
    
    struct UnsignedTransactionDataInfo {
        let chainId: UInt32
        let keyId: UInt32
        let data: ATUInt256
    }
    
    public enum TransactionDirection : Int {
        case sent = 1
        case received = 2
        case moved = 3
        
        public var description: String {
            get {
                switch self {
                case .sent:
                    return NSLocalizedString("sent", tableName: nil, bundle: Bundle.main, value: "Sent", comment: "")
                case .received:
                    return NSLocalizedString("received", tableName: nil, bundle: Bundle.main, value: "Received", comment: "")
                case .moved:
                    return NSLocalizedString("moved", tableName: nil, bundle: Bundle.main, value: "Moved", comment: "")
                }
            }
        }
    }
    
    internal(set) public var currency: ATCryptocurrencyType
    internal(set) public var amount = ATUInt256(0)
    internal(set) public var amountString = "0"
    internal(set) public var fee = ATUInt256(0)
    internal(set) public var feeString = "0"
    internal(set) public var totalAmount = ATUInt256(0)
    internal(set) public var totalAmountString = "0"
    internal(set) public var address = ""
    internal(set) public var direction: TransactionDirection
    internal(set) public var date: Date = Date(timeIntervalSince1970: 0)
    internal(set) public var message = ""
    internal(set) public var detailDescription: String = ""
    
    internal(set) public var isTokenTransfer = false
    internal(set) public var tokenInfo: ATTokenInfo?
    internal(set) public var tokenAmount: ATUInt256?
    internal(set) public var tokenAmountString: String = "0"
    
    var object: AnyObject?
    var unsignedTransactionDataInfos: [UnsignedTransactionDataInfo]?
    var rsvSignatures: [Data]?
    var ownAddress: String?
    
    init(_ currency: ATCryptocurrencyType, _ direction: TransactionDirection, _ object: AnyObject?) {
        self.currency = currency
        self.direction = direction
        self.object = object
    }
}

extension Data {
    func toDER() -> Data? {
        let rawHalfLength: Int = 65 / 2
        let derFormatP: [UInt8] = [0x30, 0x44, 0x02, 0x20] // for positive
        let derFormatN: [UInt8] = [0x30, 0x45, 0x02, 0x21, 0x00] // for negative, padding a zero byte
        let raw = [UInt8](self)
        var der: [UInt8] = []
        
        guard raw.count == 65 else { return nil }
        
        if (raw[0] & 0x80) != 0 {
            // R value negative
            der.append(contentsOf: derFormatN)
        }
        else {
            der.append(contentsOf: derFormatP)
        }
        
        // copy R
        for index in 0..<rawHalfLength {
            der.append(raw[index])
        }
        
        // 0x02 <len S>
        der.append(0x02)
        der.append(0x20)
        
        // copy S
        for index in rawHalfLength..<(rawHalfLength * 2) {
            der.append(raw[index])
        }
        
        return Data(der)
    }
}
