//
//  KeychainProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 9/4/24.
//

import Foundation
import Utilities

public final class KeychainProvider<Value>: StorageProviding
where Value: Codable & Sendable {
    private let identifier: String
    private let prefix: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
        ]
    }
    
    private var tag: String {
        prefix + "." + identifier
    }
    
    public init(identifier: String, prefix: String, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        self.identifier = identifier
        self.prefix = prefix
        self.encoder = encoder
        self.decoder = decoder
    }
    
    public func read() -> Value? {
        let query: [String: Any] = query + [
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        
        var item: CFTypeRef?
        
        guard SecItemCopyMatching(query as CFDictionary, &item) == noErr else {
            return nil
        }
        
        guard let item = item as? [String: Any],
            let data = item[kSecValueData as String] as? Data
        else {
            return nil
        }
        
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            print("Unable to decode value from keychain. Deleting the value because it's no longer in a format that can be decoded.")
            SecItemDelete(query as CFDictionary)
            return nil
        }
    }
    
    public func write(value: Value) throws {
        do {
            let attributes = [
                kSecValueData as String: try encoder.encode(value)
            ]
            
            var result = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            
            switch result {
            case errSecItemNotFound:
                let query = query + attributes
                result = SecItemAdd(query as CFDictionary, nil)
            default:
                break
            }
            
            guard result == noErr else {
                throw "Unable to add keychain item (osstatus: \(result))"
            }
        } catch {
            throw error
        }
    }
}
