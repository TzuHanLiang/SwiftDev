//
//  BRBIP39.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/12/4.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation
import BRCore

private func secureAllocate(allocSize: CFIndex, hint: CFOptionFlags, info: UnsafeMutableRawPointer?)
    -> UnsafeMutableRawPointer?
{
    guard let ptr = malloc(MemoryLayout<CFIndex>.stride + allocSize) else { return nil }
    // keep track of the size of the allocation so it can be cleansed before deallocation
    ptr.storeBytes(of: allocSize, as: CFIndex.self)
    return ptr.advanced(by: MemoryLayout<CFIndex>.stride)
}

private func secureDeallocate(ptr: UnsafeMutableRawPointer?, info: UnsafeMutableRawPointer?)
{
    guard let ptr = ptr else { return }
    let allocSize = ptr.load(fromByteOffset: -MemoryLayout<CFIndex>.stride, as: CFIndex.self)
    memset(ptr, 0, allocSize) // cleanse allocated memory
    free(ptr.advanced(by: -MemoryLayout<CFIndex>.stride))
}

private func secureReallocate(ptr: UnsafeMutableRawPointer?, newsize: CFIndex, hint: CFOptionFlags,
                              info: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
{
    // there's no way to tell ahead of time if the original memory will be deallocted even if the new size is smaller
    // than the old size, so just cleanse and deallocate every time
    guard let ptr = ptr else { return nil }
    let newptr = secureAllocate(allocSize: newsize, hint: hint, info: info)
    let allocSize = ptr.load(fromByteOffset: -MemoryLayout<CFIndex>.stride, as: CFIndex.self)
    if (newptr != nil) { memcpy(newptr, ptr, (allocSize < newsize) ? allocSize : newsize) }
    secureDeallocate(ptr: ptr, info: info)
    return newptr
}

class BRBIP39 : ATBIP39Abstraction {
    
    // since iOS does not page memory to disk, all we need to do is cleanse allocated memory prior to deallocation
    private let secureAllocator: CFAllocator = {
        var context = CFAllocatorContext()
        context.version = 0;
        CFAllocatorGetContext(kCFAllocatorDefault, &context)
        context.allocate = secureAllocate
        context.reallocate = secureReallocate;
        context.deallocate = secureDeallocate;
        return CFAllocatorCreate(kCFAllocatorDefault, &context).takeRetainedValue()
    }()
    
    required init() {
        
    }
    
    override func encodeEntropy(Entropy entropy: [UInt8], WordList wordList: [String]) -> String? {
        return autoreleasepool {
            let entropyRef = entropy.withUnsafeBufferPointer({ (pointer: UnsafeBufferPointer<UInt8>) -> UnsafePointer<UInt8> in
                return pointer.baseAddress!
            })
            var words = wordList.map { (string: String) -> UnsafePointer<Int8>? in
                return (string as NSString).utf8String
            }
            
            let mnemonicLen = BRBIP39Encode(nil, 0, &words, entropyRef, entropy.count)
            var mnenonicData = CFDataCreateMutable(secureAllocator, mnemonicLen) as Data
            mnenonicData.count = mnemonicLen
            guard mnenonicData.withUnsafeMutableBytes({
                BRBIP39Encode($0, mnemonicLen, &words, entropyRef, entropy.count)
            }) == mnenonicData.count else { return nil }
            let mnenonic = CFStringCreateFromExternalRepresentation(secureAllocator, mnenonicData as CFData, CFStringBuiltInEncodings.UTF8.rawValue) as String
            
            return mnenonic
        }
    }
    
    override func deriveSeed(Mnemonic mnemonic: String, Passphrase passphrase: String?) -> Data? {
        return autoreleasepool {
            guard let nfkdMnemonic = CFStringCreateMutableCopy(secureAllocator, 0, mnemonic as CFString)
                else { return nil }
            CFStringNormalize(nfkdMnemonic, .KD)
            
            var nfkdPassphrase: String? = nil
            if let passphrase = passphrase, passphrase.count > 0 {
                let nfkd = CFStringCreateMutableCopy(secureAllocator, 0, passphrase as CFString)
                CFStringNormalize(nfkd, .KD)
                nfkdPassphrase = nfkd! as String
            }
            
            var seed = UInt512()
            BRBIP39DeriveKey(&seed, nfkdMnemonic as String, nfkdPassphrase)
            
            return Data.init(bytes: &seed, count: 64)
        }
    }
    
    override func verifyMnemonic(Mnemonic mnemonic: String, WordList wordList: [String]) -> Bool {
        return autoreleasepool {
            guard let nfkdMnemonic = CFStringCreateMutableCopy(secureAllocator, 0, mnemonic as CFString)
                else { return false }
            CFStringNormalize(nfkdMnemonic, .KD)
            
            var words = wordList.map { (string: String) -> UnsafePointer<Int8>? in
                return (string as NSString).utf8String
            }
            
            return BRBIP39Decode(nil, 0, &words, nfkdMnemonic as String) > 0
        }
    }
}
