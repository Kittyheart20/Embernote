//
//  Models.swift
//  EmberNote
//

import SwiftUI
import Foundation

struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct Mood: Equatable, Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let emoji: String
    let color: Color
    let isCustom: Bool
    let rating: Double // Scale from -5 (most negative) to 5 (most positive)
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case color
        case isCustom
        case rating
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encode(rating, forKey: .rating)
        let colorString = color.description
        try container.encode(colorString, forKey: .color)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decode(String.self, forKey: .emoji)
        isCustom = try container.decode(Bool.self, forKey: .isCustom)
        rating = try container.decode(Double.self, forKey: .rating)
        let colorString = try container.decode(String.self, forKey: .color)
        color = .purple // Default color, you might want to implement proper color decoding
    }
    
    init(id: UUID = UUID(), name: String, emoji: String, color: Color, rating: Double, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.isCustom = isCustom
        self.rating = rating
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct MoodEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let mood: Mood
    let notes: String
    let tags: [Tag]
    
    init(date: Date, mood: Mood, notes: String, tags: [Tag] = []) {
        self.id = UUID()
        self.date = date
        self.mood = mood
        self.notes = notes
        self.tags = tags
    }
}

struct ReflectionEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let prompt: String
    let reflection: String
    let aiResponse: String
    
    init(date: Date = Date(), prompt: String, reflection: String, aiResponse: String) {
        self.id = UUID()
        self.date = date
        self.prompt = prompt
        self.reflection = reflection
        self.aiResponse = aiResponse
    }
}

struct ReflectionPrompt: Identifiable {
    let id = UUID()
    let question: String
    let systemPrompt: String
    var response: String?
}

struct MoodDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double // 0-4 scale where 0 is saddest and 4 is happiest
} 