class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func getSuggestion(for entry: MoodEntry, previousEntries: [MoodEntry]) async throws -> String {
        let moodsDescription = entry.moods.map { "\($0.emoji) \($0.name) (rating: \($0.rating))" }.joined(separator: ", ")
        
        let prompt = """
        Based on this mood entry, provide a brief, supportive suggestion:
        
        Current Entry:
        Moods: \(moodsDescription)
        Notes: \(entry.notes)
        Tags: \(entry.tags.map { $0.name }.joined(separator: ", "))
        
        Keep the response under 100 words, focusing on immediate, actionable support that addresses the combination of moods.
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
    
    // ... existing code ...
} 