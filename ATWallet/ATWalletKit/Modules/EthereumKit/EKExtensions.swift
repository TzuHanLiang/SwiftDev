//
//  EKExtensions.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/10/9.
//

import Foundation
import CryptoEthereumSwift
import EthereumKit

extension Base58 {
    private static let baseAlphabets = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    private static var zeroAlphabet: Character = "1"
    private static var base: Int = 58
    
    private static func sizeFromBase(size: Int) -> Int {
        return size * 733 / 1000 + 1
    }
    
    static func decode(_ string: String) -> Data? {
        guard !string.isEmpty else { return nil }
        
        var zerosCount = 0
        var length = 0
        for c in string {
            if c != zeroAlphabet { break }
            zerosCount += 1
        }
        let size = sizeFromBase(size: string.lengthOfBytes(using: .utf8) - zerosCount)
        var decodedBytes: [UInt8] = Array(repeating: 0, count: size)
        for c in string {
            guard let baseIndex = baseAlphabets.firstIndex(of: c) else { return nil }
            
            var carry = baseIndex.utf16Offset(in: string)
            var i = 0
            for j in (0...decodedBytes.count - 1).reversed() where carry != 0 || i < length {
                carry += base * Int(decodedBytes[j])
                decodedBytes[j] = UInt8(carry % 256)
                carry /= 256
                i += 1
            }
            
            assert(carry == 0)
            length = i
        }
        
        // skip leading zeros
        var zerosToRemove = 0
        
        for b in decodedBytes {
            if b != 0 { break }
            zerosToRemove += 1
        }
        decodedBytes.removeFirst(zerosToRemove)
        
        return Data(repeating: 0, count: zerosCount) + Data(decodedBytes)
    }
}
