//
//  Data+SHA256.swift
//  Reynard
//
//  SHA-256 hex digest. Uses CryptoKit on iOS 13+, CommonCrypto on iOS 12
//  (CryptoKit is iOS 13+). 见 AGENTS.md“iOS 12 兼容门禁清单”.
//

import Foundation
import CryptoKit
import CommonCrypto

extension Data {
    var sha256Hex: String {
        if #available(iOS 13.0, *) {
            return SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
