//
//  ATWalletKitTests.swift
//  ATWalletKitTests
//
//  Created by Joshua on 2019/7/30.
//

import XCTest
import ATWalletKit

class ATWalletKitTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
#if os(OSX)
    func testUSB() {
        class USBDeviceCallbackHandler : ATDeviceManagerDelegate, ATDeviceDelegate {
            public var foundDevice: ATDevice? = nil
            public var connected = false
            public var commandSuccess = false
            
            func deviceManager(_ deviceManager: ATDeviceManager, didUpdateState state: ATDeviceManagerState) {
                ATLog.debug("device manager did update state: \(state)")
            }
            
            func deviceManager(_ deviceManager: ATDeviceManager, didDiscover device: ATDevice) {
                ATLog.debug("device manager did discover device: \(device.name)")
                deviceManager.stopScan()
                self.foundDevice = device
                device.delegate = self
                device.connect()
            }
            func deviceManager(_ deviceManager: ATDeviceManager, didLose device: ATDevice) {
                // do nothing
            }
            
            func deviceDidConnect(_ device: ATDevice) {
                ATLog.debug("device did connect, name: \(device.name)")
                self.connected = true
                let getVersionInfoCmd: [UInt8] = [0x00, 0x77, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                device.send(Data(getVersionInfoCmd)) { (data, error) in
                    if error != nil {
                        ATLog.debug("Error: \(error!.description)")
                        return
                    }
                    guard let response = data else { return }
                    ATLog.debug("Response: \(response as NSData)")
                    if response[response.count - 2] == 0x90, response[response.count - 1] == 0x00 {
                        self.commandSuccess = true
                    }
                }
            }
            
            func deviceDidDisconnect(_ device: ATDevice) {
                ATLog.debug("device did disconnect: \(device.name)")
                self.connected = false
            }
            
            func deviceDidFailToConnect(_ device: ATDevice) {
                ATLog.debug("device did fail to connect: \(device.name)")
                self.connected = false
            }
        }
        let expectation = XCTestExpectation(description: "USB Test")
        let deviceManager: ATDeviceManager = ATUSBDeviceManager.shared
        let callbackHandler = USBDeviceCallbackHandler()
        deviceManager.delegate = callbackHandler
        deviceManager.scan()
        _ = XCTWaiter.wait(for: [expectation], timeout: 3)
        XCTAssert(callbackHandler.connected, "Failed to connect to USB device")
        XCTAssert(callbackHandler.commandSuccess, "Failed to execute command")
        callbackHandler.foundDevice?.disconnect()
    }
#endif

    func testBLE() {
        class BLEDeviceCallbackHandler : ATDeviceManagerDelegate, ATDeviceDelegate {
            public var foundDevice: ATDevice? = nil
            public var connected = false
            public var commandSuccess = false
            
            func deviceManager(_ deviceManager: ATDeviceManager, didUpdateState state: ATDeviceManagerState) {
                ATLog.debug("device manager did update state: \(state)")
                deviceManager.scan()
            }
            
            func deviceManager(_ deviceManager: ATDeviceManager, didDiscover device: ATDevice) {
                ATLog.debug("device manager did discover device: \(device.name)")
                deviceManager.stopScan()
                self.foundDevice = device
                device.delegate = self
                device.connect()
            }
            
            func deviceDidConnect(_ device: ATDevice) {
                ATLog.debug("device did connect, name: \(device.name)")
                self.connected = true
                let getVersionInfoCmd: [UInt8] = [0x00, 0x77, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                device.send(Data(getVersionInfoCmd)) { (data, error) in
                    if error != nil {
                        ATLog.debug("Error: \(error!.description)")
                        return
                    }
                    guard let response = data else { return }
                    ATLog.debug("Response: \(response as NSData)")
                    if response[response.count - 2] == 0x90, response[response.count - 1] == 0x00 {
                        self.commandSuccess = true
                    }
                }
            }
            
            func deviceDidDisconnect(_ device: ATDevice) {
                ATLog.debug("device did disconnect: \(device.name)")
                self.connected = false
            }
            
            func deviceDidFailToConnect(_ device: ATDevice) {
                ATLog.debug("device did fail to connect: \(device.name)")
                self.connected = false
            }
        }
        let expectation = XCTestExpectation(description: "BLE Test")
        let deviceManager: ATDeviceManager = ATBLEDeviceManager.shared
        let callbackHandler = BLEDeviceCallbackHandler()
        deviceManager.delegate = callbackHandler
        _ = XCTWaiter.wait(for: [expectation], timeout: 10)
        XCTAssert(callbackHandler.connected, "Failed to connect to BLE device")
        XCTAssert(callbackHandler.commandSuccess, "Failed to execute command")
        callbackHandler.foundDevice?.disconnect()
    }

    /*
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    */
}
