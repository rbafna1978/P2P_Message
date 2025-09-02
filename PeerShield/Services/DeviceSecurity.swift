//
//  DeviceSecurity.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import Foundation
import UIKit
import CryptoKit

enum DeviceSecurity {
    static func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static func isJailbrokenHeuristic() -> Bool {
        // Non-exhaustive heuristics; avoids private APIs.
        if isSimulator() { return false } // simulators often trigger false positives
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        if suspiciousPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) { return true }
        // Can we write outside sandbox?
        let test = "/private/ps_jb_test.txt"
        do {
            try "x".write(toFile: test, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: test)
            return true
        } catch {}
        return false
    }

    static func deviceChangeHeuristic() -> Bool {
        // Persist identifierForVendor hash; if unexpectedly changes, treat as risk.
        let key = "ps.idfv.hash"
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let hash = idfv.data(using: .utf8)!.sha256Base64()
        let stored = UserDefaults.standard.string(forKey: key)
        if stored == nil {
            UserDefaults.standard.set(hash, forKey: key)
            return false
        }
        return stored != hash
    }
}

fileprivate extension Data {
    func sha256Base64() -> String {
        let d = SHA256.hash(data: self)
        return Data(d).base64EncodedString()
    }
}
