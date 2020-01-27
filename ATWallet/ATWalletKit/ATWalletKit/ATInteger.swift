//
//  ATInteger.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/1/10.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Foundation

extension Decimal {
    public static func % (l: Decimal, r: Decimal) -> Decimal {
        let dividend = NSDecimalNumber(decimal: l)
        let divisor = NSDecimalNumber(decimal: r)
        let quotient: NSDecimalNumber = dividend.dividing(by: divisor, withBehavior: NSDecimalNumberHandler(roundingMode: .down, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false))
        let subtractAmount: NSDecimalNumber = quotient.multiplying(by: divisor)
        let remainder: NSDecimalNumber = dividend.subtracting(subtractAmount)
        return remainder as Decimal
    }
}

fileprivate struct ATInteger {
    var value: [UInt8]
    
    init(_ bytes: [UInt8]) {
        self.value = bytes
    }
    
    init(_ value: [UInt64]) {
        self.value = []
        for v in value {
            var value = v
            let bytes = withUnsafePointer(to: &value) { (pointer) -> [UInt8] in
                let size = MemoryLayout.size(ofValue: pointer.pointee)
                return pointer.withMemoryRebound(to: UInt8.self, capacity: size, { (pointer) -> [UInt8] in
                    return Array(UnsafeBufferPointer<UInt8>(start: pointer, count: size))
                })
            }
            self.value.append(contentsOf: bytes)
        }
    }
    
    func toUInt64() -> UInt64 {
        var value: UInt64 = 0
        for i in 0..<min(self.value.count, 8) {
            value |= UInt64(self.value[i]) << (i * 8)
        }
        return value
    }
}

public struct ATUInt128 {
    private var value: ATInteger
    
    public var bytes: [UInt8] {
        get {
            return value.value
        }
    }
    
    public init(_ value: UInt64) {
        self.value = ATInteger([value, 0])
    }
    
    public init(_ h64: UInt64, _ l64: UInt64) {
        self.value = ATInteger([l64, h64])
    }
}

public struct ATUInt256 {
    private var value: ATInteger
    
    public var bytes: [UInt8] {
        get {
            return value.value
        }
    }
    
    public var uint64: UInt64 {
        return self.value.toUInt64()
    }
    
    public var decimal: Decimal {
        return Decimal(self.uint64)
    }
    
    public init(_ value: UInt64) {
        self.value = ATInteger([value, 0, 0, 0])
    }
    
    public init(_ first64: UInt64, _ second64: UInt64, _ third64: UInt64, _ fourth64: UInt64) {
        self.value = ATInteger([first64, second64, third64, fourth64])
    }
    
    public init(_ bytes: [UInt8]) {
        var value: [UInt8] = []
        for i in 0..<min(bytes.count, 32) {
            value.append(bytes[i])
        }
        if bytes.count < 32 {
            for _ in bytes.count..<32 {
                value.append(0)
            }
        }
        self.value = ATInteger(value)
    }
    
    public init(decimal value: Decimal) {
        let value64 = NSDecimalNumber(decimal: value).uint64Value
        self.value = ATInteger([value64, 0, 0, 0])
    }
    
    public func toUInt64() -> UInt64 {
        return self.value.toUInt64()
    }
}

extension ATUInt256 {
    public static func < (l: ATUInt256, r: ATUInt256) -> Bool {
        for index in (0..<l.value.value.count).reversed() {
            if l.value.value[index] < r.value.value[index] { return true }
            if l.value.value[index] > r.value.value[index] { return false }
        }
        return false
    }
    
    public static func < (l: UInt64, r: ATUInt256) -> Bool {
        return ATUInt256(l) < r
    }
    
    public static func < (l: ATUInt256, r: UInt64) -> Bool {
        return l < ATUInt256(r)
    }
    
    public static func <= (l: UInt64, r: ATUInt256) -> Bool {
        return ATUInt256(l) < r || ATUInt256(l) == r
    }
    
    public static func <= (l: ATUInt256, r: UInt64) -> Bool {
        return l < ATUInt256(r) || l == ATUInt256(r)
    }
    
    public static func > (l: ATUInt256, r: ATUInt256) -> Bool {
        for index in (0..<l.value.value.count).reversed() {
            if l.value.value[index] > r.value.value[index] { return true }
            if l.value.value[index] < r.value.value[index] { return false }
        }
        return false
    }
    
    public static func > (l: ATUInt256, r: UInt64) -> Bool {
        return l > ATUInt256(r)
    }
    
    public static func > (l: UInt64, r: ATUInt256) -> Bool {
        return ATUInt256(l) > r
    }
    
    public static func >= (l: UInt64, r: ATUInt256) -> Bool {
        return ATUInt256(l) > r || ATUInt256(l) == r
    }
    
    public static func >= (l: ATUInt256, r: UInt64) -> Bool {
        return l > ATUInt256(r) || l == ATUInt256(r)
    }
}

extension ATUInt256: Equatable {
    public static func == (l: ATUInt256, r: ATUInt256) -> Bool {
        for i in 0..<32 {
            if l.value.value[i] != r.value.value[i] { return false }
        }
        return true
    }
    
    public static func == (l: UInt64, r: ATUInt256) -> Bool {
        return ATUInt256(l) == r
    }
    
    public static func == (l: ATUInt256, r: UInt64) -> Bool {
        return l == ATUInt256(r)
    }
    
    public static func != (l: ATUInt256, r: ATUInt256) -> Bool {
        return !(l == r)
    }
    
    public static func != (l: UInt64, r: ATUInt256) -> Bool {
        return ATUInt256(l) != r
    }
    
    public static func != (l: ATUInt256, r: UInt64) -> Bool {
        return l != ATUInt256(r)
    }
}

extension ATUInt256 {
    public static func + (l: ATUInt256, r: ATUInt256) -> ATUInt256 {
        var result = ATUInt256(0)
        var carry: UInt16 = 0
        for index in 0..<result.value.value.count {
            let sum: UInt16 = UInt16(l.value.value[index]) + UInt16(r.value.value[index])
            carry = sum >> 32
            result.value.value[index] = UInt8(sum & 0xFF)
        }
        let overflow = carry > 0
        if overflow {
            // TODO: throw error on overflow
        }
        return result
    }
    
    public static func - (l: ATUInt256, r: ATUInt256) -> ATUInt256 {
        var result = ATUInt256(0)
        var borrow: UInt16 = 0
        for index in 0..<result.value.value.count {
            var diff: UInt16 = 0
            let left = UInt16(l.value.value[index]) - borrow
            let right = UInt16(r.value.value[index])
            if left >= right {
                diff = left - right
            }
            else {
                borrow = 1
                diff = (0x100 | left) - right
            }
            result.value.value[index] = UInt8(diff)
        }
        let negative = borrow > 0
        if negative {
            // TODO: throw error on negative
        }
        return negative ? ATUInt256(0) : result
    }
    
    public static func += (l: inout ATUInt256, r: ATUInt256) {
        l = l + r
    }
    
    public static func -= (l: inout ATUInt256, r: ATUInt256) {
        l = l - r
    }
}
