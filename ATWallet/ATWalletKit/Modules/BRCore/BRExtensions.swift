//
//  BRExtensions.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/10/9.
//

import Foundation
import BRCore

extension BRMasterPubKey {
    func deriveCompressedPubKey(_ chain: UInt32, _ index: UInt32) -> [UInt8] {
        let pubKeyPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 33)
        let pubKeyLen = BRBIP32PubKey(pubKeyPointer, 33, self, chain, index)
        var pubKeyArray = [UInt8]()
        for index in 0..<pubKeyLen {
            pubKeyArray.append(pubKeyPointer[index])
        }
        pubKeyPointer.deallocate()
        return pubKeyArray
    }
}
