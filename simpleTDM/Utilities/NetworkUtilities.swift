//
//  NetworkUtilities.swift
//  TestWirelessNetworking
//
//  Created by Wirawit Rueopas on 11/7/2558 BE.
//  Copyright © 2558 Wirawit Rueopas. All rights reserved.
//

import Foundation

class NetworkUtilities {
    // Get the local ip addresses used by this node
    static let sharedInstance = NetworkUtilities()
    
    func getIFAddresses() -> [NetInfo] {
        var addresses = [NetInfo]()
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }
            
        // For each interface ...
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            var addr = ptr.pointee.ifa_addr.pointee
            
            // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        let address = String(cString: hostname)
                        var net = ptr.pointee.ifa_netmask.pointee
                        var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(&net, socklen_t(net.sa_len), &netmaskName, socklen_t(netmaskName.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        let netmask = String(cString: netmaskName)
                        addresses.append(NetInfo(ip: address, netmask: netmask))
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return addresses
    }
    
    // Return IP address of WiFi interface (en0) as a String, or `nil`
    func getMyWiFiAddress() -> NetInfo? {
        var address : String = "error"
        var netmsk : String = "error"
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            // Check interface name:
            if addrFamily != UInt8(AF_INET) && addrFamily != UInt8(AF_INET6) { continue }
            
            let name = String(cString: interface.ifa_name)
            if !name.starts(with: "en") { continue }
            
            
            // Convert interface address to a human readable string:
            var addr = interface.ifa_addr.pointee
            var netmask = interface.ifa_netmask.pointee
            
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            var netmaskname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            
            getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, socklen_t(0), NI_NUMERICHOST)
            getnameinfo(&netmask, socklen_t(interface.ifa_netmask.pointee.sa_len),
                        &netmaskname, socklen_t(netmaskname.count),
                        nil, socklen_t(0), NI_NUMERICHOST)
            
            address = String(cString: hostname)
            if address.count == 0 {
                address = "error"
                continue
            }
            netmsk = String(cString: netmaskname)
            if netmsk.count == 0 {
                netmsk = "error"
                continue
            }
        }
        
        freeifaddrs(ifaddr)
        
        if address == "error" || netmsk == "error" {
            return nil
        }
        
        return NetInfo(ip: address, netmask: netmsk)
    }
    
}

struct NetInfo {
    // IP Address
    let ip: String
    
    // Netmask Address
    let netmask: String
    
    // CIDR: Classless Inter-Domain Routing
    var cidr: Int {
        var cidr = 0
        for number in binaryRepresentation(s: netmask) {
            let numberOfOnes = number.components(separatedBy: "1").count - 1
            cidr += numberOfOnes
        }
        return cidr
    }
    
    // Network Address
    var network: String {
        return bitwise(op: &, net1: ip, net2: netmask)
    }
    
    // Broadcast Address
    var broadcast: String {
        let inverted_netmask = bitwise(op: ~, net1: netmask)
        let broadcast = bitwise(op: |, net1: network, net2: inverted_netmask)
        return broadcast
    }
    
    private func binaryRepresentation(s: String) -> [String] {
        var result: [String] = []
        
        for numbers in s.components(separatedBy: ".") {
            if let intNumber = Int(numbers) {
                if let binary = Int(String(intNumber, radix: 2)) {
                    result.append(NSString(format: "%08d", binary) as String)
                }
            }
        }
        return result
    }
    
    private func bitwise(op: (UInt8,UInt8) -> UInt8, net1: String, net2: String) -> String {
        let net1numbers = toInts(networkString: net1)
        let net2numbers = toInts(networkString: net2)
        var result = ""
        for i in 0..<net1numbers.count {
            result += "\(op(net1numbers[i],net2numbers[i]))"
            if i < (net1numbers.count-1) {
                result += "."
            }
        }
        return result
    }
    
    private func bitwise(op: (UInt8) -> UInt8, net1: String) -> String {
        let net1numbers = toInts(networkString: net1)
        var result = ""
        for i in 0..<net1numbers.count {
            result += "\(op(net1numbers[i]))"
            if i < (net1numbers.count-1) {
                result += "."
            }
        }
        return result
    }
    
    private func toInts(networkString: String) -> [UInt8] {
        return networkString.components(separatedBy: ".").map{UInt8($0)!}
    }
}
