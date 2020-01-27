//
//  ATAbstractWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/12/18.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

protocol ATAbstractWalletDelegate {
    func abstractWalletDidUpdateBalance(_ balance: ATUInt256)
    func abstractWalletDidStartSync()
    func abstractWalletDidStopSync(_ error: ATError?)
    func abstractWalletDidRequestResync()
    func abstractWalletDidUpdateTransaction()
    func abstractWalletDidUpdateTokens()
    func abstractWalletDidGenerateTransactionDataForSigning(_ transaction: ATCryptocurrencyTransaction)
    func abstractWalletDidFailToGenerateTransactionDataForSigning(_ transaction: ATCryptocurrencyTransaction, _ error: ATError)
    func abstractWalletDidGenerateSignedTransaction(_ transaction: ATCryptocurrencyTransaction)
    func abstractWalletDidFailToGenerateSignedTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError)
    func abstractWalletDidPublishTransaction(_ transaction: ATCryptocurrencyTransaction)
    func abstractWalletDidFailToPublishTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError)
    func abstractWalletDidUpdateNumberOfUsedPublicKey(_ chainId: UInt32, _ count: UInt32);
}

class ATAbstractWallet : NSObject {
    
    var delegate: ATAbstractWalletDelegate?
    
    init(Delegate delegate: ATAbstractWalletDelegate) {
        self.delegate = delegate
    }
        
    func startSync(_ autoSync: Bool = true) {
        ATLog.debug("\(#function) needs to be implementd")
    }
    
    func stopAutoSync() {
        ATLog.debug("\(#function) needs to be implementd")
    }
    
    func getBalance() -> ATUInt256 {
        ATLog.debug("\(#function) needs to be implementd")
        return ATUInt256(0)
    }
    
    func getBalanceString() -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return "0"
    }
    
    func getTransactions() -> [ATCryptocurrencyTransaction] {
        ATLog.debug("\(#function) needs to be implementd")
        return []
    }
    
    func getTokens() -> [ATCryptocurrencyToken]? {
        ATLog.debug("\(#function) needs to be implementd")
        return nil
    }
    
    func getReceivingAddress() -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return ""
    }
    
    func getReceivingAddressesWithFormat() -> [String: String]? {
        ATLog.debug("\(#function) needs to be implementd")
        return nil
    }
    
    func checkAddressValidity(_ address: String) -> Bool {
        ATLog.debug("\(#function) needs to be implementd")
        return false
    }
    
    func containAddress(_ address: String) -> Bool {
        ATLog.debug("\(#function) needs to be implementd")
        return false
    }
    
    func calculateMinimumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func calculateLowFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func calculateMediumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func calculateHighFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func getMaxOutputAmount() -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return "0"
    }
    
    func getMinOutputAmount() -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func createTransaction(_ amount: String, _ fee: String, _ address: String, _ message: String? = nil) -> ATCryptocurrencyTransaction? {
        ATLog.debug("\(#function) needs to be implementd")
        return nil
    }
    
    func destroyTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function) needs to be implementd")
    }
    
    func generateTransactionDataForSigning(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function) needs to be implementd")
    }
    
    func generateSignedTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function) needs to be implementd")
    }
    
    func publishTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function) needs to be implementd")
    }
    
    func calculateTokenMinimumFee(_ token: ATCryptocurrencyToken, _ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func calculateTokenLowFee(_ token: ATCryptocurrencyToken, _ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func calculateTokenMediumFee(_ token: ATCryptocurrencyToken, _ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func calculateTokenHighFee(_ token: ATCryptocurrencyToken, _ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func getTokenMaxOutputAmount(_ token: ATCryptocurrencyToken) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return "0"
    }
    
    func getTokenMinOutputAmount(_ token: ATCryptocurrencyToken) -> String {
        ATLog.debug("\(#function) needs to be implementd")
        return String(UInt64.max)
    }
    
    func createTokenTransaction(_ token: ATCryptocurrencyToken, _ amount: String, _ fee: String, _ address: String, _ message: String? = nil) -> ATCryptocurrencyTransaction? {
        ATLog.debug("\(#function) needs to be implementd")
        return nil
    }
}
