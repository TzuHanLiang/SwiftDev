//
//  CAExtensions.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/12/31.
//

import Foundation

extension ATCryptocurrencyType {
    var cryptoApiUrlComponent: String {
        switch self {
        case .btc:
            return "btc"
        case .bch:
            return "bch"
        case .ltc:
            return "ltc"
        case .doge:
            return "doge"
        case .dash:
            return "dash"
        case .eth:
            return "eth"
        }
    }
}
