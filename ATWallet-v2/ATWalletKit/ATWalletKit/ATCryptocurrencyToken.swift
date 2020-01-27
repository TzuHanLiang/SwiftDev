//
//  ATCryptocurrencyToken.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/12/24.
//

import Foundation
import EthereumKit

public struct ATTokenInfo {
    public let address: String
    public let name: String
    public let symbol: String
    public let type: String
    public let decimals: UInt
    public let totalSupply: Double
}

public class ATCryptocurrencyToken: NSObject {
    
    public let info: ATTokenInfo
    public var exchangeRates: [String: Double] = [:]
    
    internal(set) public var transactions: [ATCryptocurrencyTransaction]
    
    var balance: BInt
    
    static public func stringToValue(_ string: String, _ decimals: UInt) -> BInt {
        var integerString = string
        var decimalString = "0"
        if let index = integerString.firstIndex(of: ".") {
            decimalString = String(integerString.suffix(from: integerString.index(after: index)))
            integerString = String(integerString.prefix(upTo: index))
            while decimalString.count < decimals {
                decimalString.append("0")
            }
        }
        var multiplierString = "1"
        while multiplierString.count <= decimals {
            multiplierString.append("0")
        }
        return (BInt(integerString, radix: 10) ?? BInt(0)) * (BInt(multiplierString, radix: 10) ?? BInt(0)) + (BInt(decimalString, radix: 10) ?? BInt(0))
    }
    
    static public func valueToString(_ value: BInt, _ decimals: UInt) -> String {
        var str = value.asString(withBase: 10)
        while str.count <= decimals {
            str.insert("0", at: str.startIndex)
        }
        let offset = str.count - Int(decimals)
        let index = str.index(str.startIndex, offsetBy: offset)
        str.insert(".", at: index)
        while str.last == "0" {
            str.removeLast()
        }
        (str.last == ".") ? str.append("0") : nil
        return str
    }
    
    public var balanceString: String {
        return ATCryptocurrencyToken.valueToString(self.balance, info.decimals)
    }

    init(_ tokenInfo: ATTokenInfo) {
        self.info = tokenInfo
        self.balance = BInt(0)
        self.transactions = []
    }
    
}
