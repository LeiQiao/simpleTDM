//
//  BlueKeyboardUtilities.swift
//  simpleTDM
//
//  Created by lei.qiao on 2018/11/14.
//  Copyright © 2018 lei.qiao. All rights reserved.
//

import Cocoa
import CoreBluetooth
import IOBluetooth

// kBluetoothDeviceClassMajorPeripheral
// kBluetoothDeviceClassMinorPeripheral1Keyboard


class BlueKeyboardUtilities: NSObject {
    static let sharedInstance = BlueKeyboardUtilities()
    
    func getAllKeyboard() -> [BlueKeyboard] {
        let allDevices = IOBluetoothDevice.pairedDevices()
        var keyboards: [BlueKeyboard] = []
        for item in allDevices! {
            if let device = item as? IOBluetoothDevice {
                // device.classOfDevice should be 9536, not sure
                
                if device.deviceClassMajor != kBluetoothDeviceClassMajorPeripheral ||
                    device.deviceClassMinor != kBluetoothDeviceClassMinorPeripheral1Keyboard {
                    continue
                }
                
                keyboards.append(BlueKeyboard(device: device))
            }
        }
        return keyboards
    }
    
    func disconnect(keyboard: BlueKeyboard) -> Bool {
        guard let pair = IOBluetoothDevicePair(device: keyboard.device) else {
            return false
        }
        
        pair.stop()
        return true
    }
    
    func connect(keyboard: BlueKeyboard) -> Bool {
        guard let pair = IOBluetoothDevicePair(device: keyboard.device) else {
            return false
        }
        if pair.device().isConnected() {
            return true
        }
        
        return (pair.start() == 0)
    }
}

struct BlueKeyboard {
    let device: IOBluetoothDevice?
    
    func getName () -> String! {
        guard let device = self.device else {
            return ""
        }
        return device.name
    }
    
    func getAddress() -> String! {
        guard let device = self.device else {
            return ""
        }
        return device.addressString
    }
    
    func isConnected () -> Bool {
        guard let device = self.device else {
            return false
        }
        return device.isConnected()
    }
}
