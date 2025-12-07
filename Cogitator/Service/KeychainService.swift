//
//  KeychainService.swift
//  Cogitator
//

import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Key not found in Keychain."
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        }
    }
}

struct KeychainService {
    private let service = "com.rongweiji.Cogitator"
    private let account = "xai_api_key"

    func save(key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecParam)
        }

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(key: key)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func update(key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecParam)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }

        if status == errSecItemNotFound {
            try save(key: key)
        }
    }

    func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func fetchKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecInternalError)
        }

        return key
    }

    func hasKey() -> Bool {
        do {
            _ = try fetchKey()
            return true
        } catch {
            return false
        }
    }
}
