import Foundation
import SwiftUI

struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func getSuggestion(for entry: MoodEntry, previousEntries: [MoodEntry]) async throws -> String {
        let prompt = """
        Based on this mood entry, provide a brief, supportive suggestion:
        
        Current Entry:
        Mood: \(entry.mood.emoji) (\(entry.mood.rating))
        Notes: \(entry.notes)
        Tags: \(entry.tags.map { $0.name }.joined(separator: ", "))
        
        Keep the response under 100 words, focusing on immediate, actionable support.
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a supportive and empathetic AI assistant. Keep responses brief and actionable."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 150
        ]
        
        return try await makeRequest(requestBody)
    }
    
    func getReflectionInsight(prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": """
                You are an empathetic AI assistant helping with mood tracking.
                Keep responses concise (max 150 words) and actionable.
                Focus on recent patterns and immediate support.
                Use a warm, supportive tone.
                """],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 250,
            "presence_penalty": 0.6,
            "frequency_penalty": 0.3
        ]
        
        return try await makeRequest(requestBody)
    }
    
    private func makeRequest(_ requestBody: [String: Any]) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        return response.choices.first?.message.content ?? "Unable to generate response"
    }
} 