//
//  CAEthereumClassicWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/12/27.
//

import Foundation

class CAEthereumClassicWallet: CAEthereumBasedWallet {
    override var NETWORK: String {
        get {
            #if TESTNET
            return "morden"
            #else
            return "mainnet"
            #endif
        }
        set {}
    }
    
    override var CHAIN_ID: Int {
        get {
            #if TESTNET
            return 62 // Ethereum Classic Testnet Morden Chain ID
            #else
            return 61 // Ethereum Classic Chain ID
            #endif
        }
        set {}
    }
    
    override var SYNC_INTERVAL: TimeInterval {
        get {
            return 60 * 2 // seconds
        }
        set {}
    }
    
    /*
    override var CRYPTOCURRENCY_TYPE: ATCryptocurrencyType {
        get {
            return ATCryptocurrencyType.etc
        }
        set {}
    }
    */
    
    override var API_KEY: String {
        get {
            return ATConstants.CRYPTOAPIS_API_KEY_ETHEREUM_CLASSIC
        }
        set {}
    }
    
    override init?(UniqueId uid: [UInt8], EarlistKeyTime timestamp: UInt32, PublicKey pubKey: [UInt8], ChainCode chainCode: [UInt8], FingerprintOfParentKey fingerprint: UInt32, Delegate delegate: ATAbstractWalletDelegate) {
        super.init(UniqueId: uid, EarlistKeyTime: timestamp, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: delegate)
    }
}
