//
//  Config.swift
//  BookQuotes
//
//  Reads configuration values from Config.plist.
//  This file should be copied from Config.plist.template and populated with your API keys.
//

import Foundation

/// Configuration values loaded from Config.plist
enum Config {
    
    /// Error thrown when configuration is invalid
    enum ConfigError: LocalizedError {
        case plistNotFound
        case keyNotFound(String)
        case invalidValue(String)
        
        var errorDescription: String? {
            switch self {
            case .plistNotFound:
                return "Config.plist not found. Please copy Config.plist.template to Config.plist and add your API key."
            case .keyNotFound(let key):
                return "Key '\(key)' not found in Config.plist"
            case .invalidValue(let key):
                return "Invalid or empty value for '\(key)' in Config.plist. Please add your API key."
            }
        }
    }
    
    /// The Anthropic API key for Claude Vision
    /// - Throws: ConfigError if the plist or key is not found
    static func anthropicAPIKey() throws -> String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist") else {
            throw ConfigError.plistNotFound
        }
        
        guard let dict = NSDictionary(contentsOfFile: path) else {
            throw ConfigError.plistNotFound
        }
        
        guard let apiKey = dict["ANTHROPIC_API_KEY"] as? String else {
            throw ConfigError.keyNotFound("ANTHROPIC_API_KEY")
        }
        
        // Check for placeholder or empty value
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty || trimmedKey == "YOUR_API_KEY_HERE" {
            throw ConfigError.invalidValue("ANTHROPIC_API_KEY")
        }
        
        return trimmedKey
    }
}
