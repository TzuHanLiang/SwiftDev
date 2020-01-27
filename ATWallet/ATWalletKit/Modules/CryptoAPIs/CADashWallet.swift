//
//  CADashWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/10/25.
//

import Foundation

class CADashWallet: CABitcoinBasedWallet {
    
    override var GAP_LIMIT: UInt32 {
        get {
            return 5 // Standard is 20
        }
        set {}
    }
    
    override var AVERAGE_CONFIRMATION_TIME: TimeInterval {
        get {
            return 2.5 * 60 // 2.5 minutes in seconds
        }
        set {}
    }
    
    override var FULL_SYNC_INTERVAL: TimeInterval {
        get {
            return 24 * 60 * 60 // 24 hours in second
        }
        set {}
    }
    
    override var PARTIAL_SYNC_INTERVAL: TimeInterval {
        get {
            return 2.5 * 60 // 2.5 minutes in second
        }
        set {}
    }
    
    override var CRYPTOCURRENCY_TYPE: ATCryptocurrencyType {
        get {
            return ATCryptocurrencyType.dash
        }
        set {}
    }
    
    override var API_KEY: String {
        get {
            return ATConstants.CRYPTOAPIS_API_KEY_DASH
        }
        set {}
    }
    
    override init?(UniqueId uid: [UInt8], EarlistKeyTime timestamp: UInt32, PublicKey pubKey: [UInt8], ChainCode chainCode: [UInt8], FingerprintOfParentKey fingerprint: UInt32, Delegate delegate: ATAbstractWalletDelegate) {
        super.init(UniqueId: uid, EarlistKeyTime: timestamp, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: delegate)
    }
    
}
