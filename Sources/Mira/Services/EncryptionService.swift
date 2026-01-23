import Foundation
import CryptoKit
import Security

/// Service for encrypting/decrypting sensitive fields using AES-GCM
/// Key is stored securely in the macOS Keychain
final class EncryptionService {
    static let shared = EncryptionService()
    
    private let keychainService = "com.snupai.Mira.encryption"
    private let keychainAccount = "masterKey"
    
    /// Use iCloud Keychain to sync key across devices
    /// Set to false for local-only encryption
    var useiCloudKeychain = true
    
    private var cachedKey: SymmetricKey?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Encrypt a string, returns Base64-encoded ciphertext
    func encrypt(_ plaintext: String) throws -> String {
        guard !plaintext.isEmpty else { return "" }
        
        let key = try getOrCreateKey()
        let data = Data(plaintext.utf8)
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return combined.base64EncodedString()
    }
    
    /// Decrypt a Base64-encoded ciphertext, returns original string
    func decrypt(_ ciphertext: String) throws -> String {
        guard !ciphertext.isEmpty else { return "" }
        
        let key = try getOrCreateKey()
        
        guard let data = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidCiphertext
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        return plaintext
    }
    
    /// Encrypt Data, returns encrypted Data (nonce + ciphertext + tag)
    func encrypt(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }
        
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return combined
    }
    
    /// Decrypt Data
    func decrypt(_ encryptedData: Data) throws -> Data {
        guard !encryptedData.isEmpty else { return Data() }
        
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    /// Check if encryption key exists
    var hasKey: Bool {
        do {
            _ = try loadKeyFromKeychain()
            return true
        } catch {
            return false
        }
    }
    
    /// Export key for backup (returns Base64)
    /// ⚠️ Handle with care - this is the master encryption key!
    func exportKey() throws -> String {
        let key = try getOrCreateKey()
        return key.withUnsafeBytes { Data($0).base64EncodedString() }
    }
    
    /// Import key from backup (Base64)
    /// ⚠️ This will replace the current key!
    func importKey(_ base64Key: String) throws {
        guard let keyData = Data(base64Encoded: base64Key),
              keyData.count == 32 else { // 256 bits
            throw EncryptionError.invalidKey
        }
        
        let key = SymmetricKey(data: keyData)
        try saveKeyToKeychain(key)
        cachedKey = key
    }
    
    /// Delete the encryption key (⚠️ makes all encrypted data unrecoverable!)
    func deleteKey() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        // Match iCloud Keychain setting
        if useiCloudKeychain {
            query[kSecAttrSynchronizable as String] = true
        }
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EncryptionError.keychainError(status)
        }
        
        cachedKey = nil
    }
    
    // MARK: - Private Methods
    
    private func getOrCreateKey() throws -> SymmetricKey {
        // Return cached key if available
        if let key = cachedKey {
            return key
        }
        
        // Try to load from Keychain
        do {
            let key = try loadKeyFromKeychain()
            cachedKey = key
            return key
        } catch EncryptionError.keyNotFound {
            // Generate new key
            let key = SymmetricKey(size: .bits256)
            try saveKeyToKeychain(key)
            cachedKey = key
            return key
        }
    }
    
    private func loadKeyFromKeychain() throws -> SymmetricKey {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Enable iCloud Keychain sync
        if useiCloudKeychain {
            query[kSecAttrSynchronizable as String] = true
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let keyData = result as? Data else {
                throw EncryptionError.invalidKey
            }
            return SymmetricKey(data: keyData)
            
        case errSecItemNotFound:
            throw EncryptionError.keyNotFound
            
        default:
            throw EncryptionError.keychainError(status)
        }
    }
    
    private func saveKeyToKeychain(_ key: SymmetricKey) throws {
        // First, try to delete existing key
        try? deleteKey()
        
        let keyData = key.withUnsafeBytes { Data($0) }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Enable iCloud Keychain sync
        if useiCloudKeychain {
            query[kSecAttrSynchronizable as String] = true
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError(status)
        }
    }
}

// MARK: - Errors

enum EncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidCiphertext
    case invalidKey
    case keyNotFound
    case keychainError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidCiphertext:
            return "Invalid ciphertext format"
        case .invalidKey:
            return "Invalid encryption key"
        case .keyNotFound:
            return "Encryption key not found"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
}

// MARK: - Property Wrapper for Encrypted Strings

/// Property wrapper that automatically encrypts/decrypts string values
/// Usage: @Encrypted var iban: String
@propertyWrapper
struct Encrypted: Codable {
    private var encryptedValue: String = ""
    
    var wrappedValue: String {
        get {
            guard !encryptedValue.isEmpty else { return "" }
            do {
                return try EncryptionService.shared.decrypt(encryptedValue)
            } catch {
                print("⚠️ Decryption failed: \(error)")
                return ""
            }
        }
        set {
            guard !newValue.isEmpty else {
                encryptedValue = ""
                return
            }
            do {
                encryptedValue = try EncryptionService.shared.encrypt(newValue)
            } catch {
                print("⚠️ Encryption failed: \(error)")
                encryptedValue = ""
            }
        }
    }
    
    init(wrappedValue: String = "") {
        self.wrappedValue = wrappedValue
    }
    
    // Codable conformance - stores encrypted value
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        encryptedValue = try container.decode(String.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(encryptedValue)
    }
}
