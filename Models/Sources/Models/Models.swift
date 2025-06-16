// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SwiftUI

public struct Tag: Identifiable, Codable, Hashable {
    public let id = UUID()
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}

public struct Mood: Identifiable, Codable, Hashable {
    public let id = UUID()
    public let name: String
    public let emoji: String
    public let color: Color
    public let rating: Double
    public let isCustom: Bool
    
    public init(name: String, emoji: String, color: Color, rating: Double, isCustom: Bool = false) {
        self.name = name
        self.emoji = emoji
        self.color = color
        self.rating = rating
        self.isCustom = isCustom
    }
}

public struct MoodEntry: Identifiable, Codable {
    public let id = UUID()
    public let date: Date
    public let moods: [Mood]
    public let notes: String
    public let tags: [Tag]
    
    public init(date: Date, moods: [Mood], notes: String, tags: [Tag]) {
        self.date = date
        self.moods = moods
        self.notes = notes
        self.tags = tags
    }
}

public struct ReflectionEntry: Identifiable, Codable {
    public let id = UUID()
    public let date: Date
    public let prompt: String
    public let reflection: String
    public let aiResponse: String
    
    public init(prompt: String, reflection: String, aiResponse: String, date: Date = Date()) {
        self.date = date
        self.prompt = prompt
        self.reflection = reflection
        self.aiResponse = aiResponse
    }
}

public struct ReflectionPrompt: Identifiable {
    public let id = UUID()
    public let question: String
    public let systemPrompt: String
    public var response: String?
    
    public init(question: String, systemPrompt: String, response: String? = nil) {
        self.question = question
        self.systemPrompt = systemPrompt
        self.response = response
    }
}

public struct MoodDataPoint: Identifiable {
    public let id = UUID()
    public let date: Date
    public let value: Double
    
    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public enum Timeframe: String, CaseIterable, Codable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

// Extension to make Color codable
extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let r = try container.decode(Double.self, forKey: .red)
        let g = try container.decode(Double.self, forKey: .green)
        let b = try container.decode(Double.self, forKey: .blue)
        let o = try container.decode(Double.self, forKey: .opacity)
        self.init(red: r, green: g, blue: b, opacity: o)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var o: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &o)
        try container.encode(r, forKey: .red)
        try container.encode(g, forKey: .green)
        try container.encode(b, forKey: .blue)
        try container.encode(o, forKey: .opacity)
    }
}
