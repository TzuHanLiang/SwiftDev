//
//  ATContants.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/9/6.
//

import Foundation

internal protocol ATConstantsProtocol {
    static var PSK: [UInt8] { get }
    static var INFURA_MAINNET_ENDPOINT: String { get }
    static var INFURA_ROPSTEN_ENDPOINT: String { get }
    static var ETHERSCAN_API_KEY: String { get }
    static var CRYPTOAPIS_API_KEY_LITECOIN: String { get }
    static var CRYPTOAPIS_API_KEY_BITCOIN: String { get }
    static var CRYPTOAPIS_API_KEY_BITCOIN_CASH: String { get }
    static var CRYPTOAPIS_API_KEY_DOGECOIN: String { get }
    static var CRYPTOAPIS_API_KEY_DASH: String { get }
    static var CRYPTOAPIS_API_KEY_ETHEREUM: String { get }
    static var CRYPTOAPIS_API_KEY_ETHEREUM_CLASSIC: String { get }
    static var CRYPTOAPIS_API_KEY_MARKET_DATA: String { get }
}

public class ATConstants: ATConstantsProtocol {
    
#if TESTNET
    public static let TESTNET = true
#else
    public static let TESTNET = false
#endif
    
    /*
    static var PSK: [UInt8] {
        // NOTE: Please apply to AuthenTrend for obtainning PSK
        return []
    }
    
    static var INFURA_MAINNET_ENDPOINT: String {
        // NOTE: Please apply to INFURA for abtainning endpoint URL
        return ""
    }
    
    static var INFURA_ROPSTEN_ENDPOINT: String {
        // NOTE: Please apply to INFURA for abtainning endpoint URL
        return ""
    }
    
    static var ETHERSCAN_API_KEY: String {
        // NOTE: Please apply to INFURA for abtainning API Key
        return ""
    }
    
    static var CRYPTOAPIS_API_KEY_LITECOIN: String {
        // NOTE: Please apply to CryptoAPIs for abtainning API Key
        return ""
    }
    
    static var CRYPTOAPIS_API_KEY_BITCOIN: String {
        // NOTE: Please apply to CryptoAPIs for abtainning API Key
        return ""
    }
    
    static var CRYPTOAPIS_API_KEY_BITCOIN_CASH: String: String {
        // NOTE: Please apply to CryptoAPIs for abtainning API Key
        return ""
    }
    
    static var CRYPTOAPIS_API_KEY_DOGECOIN: String: String {
        // NOTE: Please apply to CryptoAPIs for abtainning API Key
        return ""
    }
    
    static var CRYPTOAPIS_API_KEY_DASH: String: String {
        // NOTE: Please apply to CryptoAPIs for abtainning API Key
        return ""
    }
    
    static var CRYPTOAPIS_API_KEY_ETHEREUM: String: String {
        // NOTE: Please apply to CryptoAPIs for abtainning API Key
        return ""
    }
    
    static var CRYPTOAPIS_API_KEY_ETHEREUM_CLASSIC: String: String {
        // NOTE: Please apply to CryptoAPIs for abtainning API Key
        return ""
    }
    */
}
