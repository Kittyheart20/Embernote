//
//  Config.swift
//  EmberNote
//

import Foundation

struct Config {
    static func getOpenAIAPIKey() -> String {
        // Method 1: Try environment variable first
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // Method 2: Try reading from Config.plist (not tracked in git)
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let apiKey = plist["OPENAI_API_KEY"] as? String, !apiKey.isEmpty {
            return apiKey
        }
        
        // Method 3: Fallback - you should set this up properly
        print("⚠️ Warning: OpenAI API key not found. Please set OPENAI_API_KEY environment variable or create Config.plist")
        return ""
    }
} 