//
//  ATLog.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/14.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

public class ATLog : NSObject {
    
    public enum Level: Int {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
    }
    
    #if DEBUG
    private static var logLevel = Level.debug
    #else
    private static var logLevel = Level.error
    #endif
    
    private static func printLog(_ tag: String, _ message: String, _ file: String, _ line: Int) {
        let fileName = (file as NSString).lastPathComponent
        #if DEBUG
        print("[\(tag)] \(message) (\(fileName): \(line))")
        #else
        NSLog("[\(tag)] \(message) (\(fileName): \(line))")
        #endif
    }
    
    public static func verbose(_ message: String, file: String = #file, line: Int = #line) {
        guard ATLog.logLevel.rawValue <= Level.verbose.rawValue else { return }
        ATLog.printLog("VERBOSE", message, file, line)
    }
    
    public static func debug(_ message: String, file: String = #file, line: Int = #line) {
        guard ATLog.logLevel.rawValue <= Level.debug.rawValue else { return }
        ATLog.printLog("DEBUG", message, file, line)
    }
    
    public static func info(_ message: String, file: String = #file, line: Int = #line) {
        guard ATLog.logLevel.rawValue <= Level.info.rawValue else { return }
        ATLog.printLog("INFO", message, file, line)
    }
    
    public static func warning(_ message: String, file: String = #file, line: Int = #line) {
        guard ATLog.logLevel.rawValue <= Level.warning.rawValue else { return }
        ATLog.printLog("WARNING", message, file, line)
    }
    
    public static func error(_ message: String, file: String = #file, line: Int = #line) {
        guard ATLog.logLevel.rawValue <= Level.error.rawValue else { return }
        ATLog.printLog("ERROR", message, file, line)
    }
    
    public static func setLogLevel(_ level: Level) {
        ATLog.logLevel = level
    }
}
