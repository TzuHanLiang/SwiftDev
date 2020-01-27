//
//  ATHDWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/5.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

public class ATHDWallet : NSObject {
    
    public enum Index: UInt8 {
        case first = 0x00
        case second = 0x01
        case any = 0xFF
    }
    
    private weak var coldWallet: ATColdWallet?
    
    internal(set) public var hdwIndex: UInt8
    internal(set) public var name: String?
    internal(set) public var wallets: [ATCryptocurrencyWallet]?
    
    internal(set) public var numberOfWallet: UInt32
    
    public var infoExpired: Bool {
        get {
            return self.wallets?.count != Int(self.numberOfWallet)
        }
    }
    
    init(Name name: String?, ColdWallet coldWallet: ATColdWallet?, HDWIndex hdwIndex: UInt8, ExistedWallets existedWalletNumber: UInt32) {
        self.name = name
        self.coldWallet = coldWallet
        self.hdwIndex = hdwIndex
        self.numberOfWallet = existedWalletNumber
        self.wallets = []
        ATLog.debug("Number of Wallet: \(existedWalletNumber)")
    }
        
    private func updateWalletInfoRecursive(_ index: UInt32, _ callback: @escaping (_ error: ATError?) -> ()) {
        self.coldWallet?.getWalletInfo(AccountIndex: index, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(.failToConnect)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(.failToUpdateWalletInfo)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(.loginRequired)
            }
            
            delegate.coldWalletDidGetWalletInfo = { (purpose, coinType, account, balance, name, numberOfExtKey, numberOfIntKey, timestamp, uniqueId, currencyType) in
                let wallet = ATCryptocurrencyWallet(ColdWallet: self.coldWallet, Purpose: purpose, CoinType: coinType, Account: account, AccountIndex: index, Name: name, Balance: balance, ExtKeys: numberOfExtKey, IntKeys: numberOfIntKey, CreationTime: timestamp, UniqueId: uniqueId, CurrencyType: currencyType)
                self.wallets?.append(wallet)
                if index == (self.numberOfWallet - 1) {
                    callback(nil)
                }
                else {
                    self.updateWalletInfoRecursive(index + 1, callback)
                }
            }
        })
    }
    
    func getExtendedPublicKeyInfo(_ path: [UInt32], _ callback: @escaping (_ key: [UInt8]?, _ chainCode: [UInt8]?, _ fingerprint: UInt32?, _ error: ATError?) -> ()) {
        self.coldWallet?.getHDWalletExtendedPublicKeyInfo(Path: path, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, nil, nil, .failToConnect)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(nil, nil, nil, .failToUpdateWalletKeyInfo)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(nil, nil, nil, .loginRequired)
            }
            
            delegate.coldWalletDidGetHDWalletExtendedPublicKeyInfo = { (key, chainCode, fingerprint) in
                callback(key, chainCode, fingerprint, nil)
            }
        })
    }
    
    public func updateWalletInfo(_ callback: @escaping (_ error: ATError?) -> ()) {
        ATLog.debug("\(#function)")
        if self.numberOfWallet == 0 {
            callback(.noWalletExisted)
            return
        }
        
        self.wallets = []
        updateWalletInfoRecursive(0, callback)
    }
    
    public func addWallet(Purpose purpose: UInt32?, Currency currency: ATCryptocurrencyType, Account account: UInt32?, Name name: String, Timestamp timestamp: UInt32, _ callback: @escaping (_ wallet: ATCryptocurrencyWallet?, _ error: ATError?) -> ()) {
        ATLog.debug("\(#function)")
        let bip44Purpose: UInt32 = 0x8000002C
        self.coldWallet?.createWallet(Purpose: purpose ?? bip44Purpose, Currency: currency, Account: account, CreationTime: timestamp, Name: name, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, .failToConnect)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(nil, .failToCreateWallet)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(nil, .loginRequired)
            }
            
            delegate.coldWalletDidFailToCreateWallet = {
                callback(nil, .failToCreateWallet)
            }
            
            delegate.coldWalletDidCreateWallet = { (wallet) in
                self.numberOfWallet += 1
                self.wallets?.append(wallet)
                callback(wallet, nil)
            }
        })
    }
    
    public func removeWallet(Wallet wallet: ATCryptocurrencyWallet, _ callback: @escaping (_ error: ATError?) -> ()) {
        ATLog.debug("\(#function)")
        self.coldWallet?.removeWallet(AccountIndex: wallet.accountIndex, UniqueId: wallet.uid, Delegate: ATColdWalletDelegate { (delegate) in
                delegate.coldWalletDidFailToConnect = {
                    callback(.failToConnect)
                }
                
                delegate.coldWalletDidFailToExecuteCommand = { (error) in
                    callback(.failToCreateWallet)
                }
                
                delegate.coldWalletNeedsLoginWithFingerprint = {
                    callback(.loginRequired)
                }
                
                delegate.coldWalletDidFailToRemoveWallet = {
                    callback(.commandError)
                }
                
                delegate.coldWalletDidRemoveWallet = {
                    let deletedAccountIndex = wallet.accountIndex
                    if let index = self.wallets?.firstIndex(of: wallet) {
                        self.numberOfWallet -= 1
                        self.wallets?.remove(at: index)
                    }
                    else {
                        let deletedWallet = wallet
                        var index = 0
                        for wallet in self.wallets ?? [] {
                            if wallet.uid == deletedWallet.uid {
                                self.numberOfWallet -= 1
                                self.wallets?.remove(at: index)
                                break
                            }
                            index += 1
                        }
                    }
                    for wallet in self.wallets ?? [] {
                        (wallet.accountIndex > deletedAccountIndex) ? wallet.accountIndex -= 1 : nil
                    }
                    callback(nil)
                }
        })
    }
    
}
