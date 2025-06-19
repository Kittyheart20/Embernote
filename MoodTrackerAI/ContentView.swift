//
//  ContentView.swift
//  EmberNote
//

import SwiftUI
import Foundation
import Models


extension Color {
    static let themeBeige = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let themeBeigeDark = Color(red: 0.95, green: 0.92, blue: 0.87)
    static let themeAccent = Color(red: 0.76, green: 0.65, blue: 0.54)
    static let themeAccentLight = Color(red: 0.85, green: 0.75, blue: 0.65)
}

class MoodStore: ObservableObject {
    @Published var entries: [MoodEntry] = []
    @Published var reflections: [ReflectionEntry] = []
    @Published var availableTags: [Tag] = [
        Tag(name: "School"),
        Tag(name: "Work"),
        Tag(name: "Relationship")
    ]
    @Published var customMoods: [Mood] = []
    @Published var suggestions: [UUID: String] = [:]
    private let saveKey = "savedMoodEntries"
    private let suggestionsKey = "savedSuggestions"
    private let reflectionsKey = "savedReflections"
    private let tagsKey = "availableTags"
    private let customMoodsKey = "customMoods"
    let openAIService: OpenAIService
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    let defaultMoods: [Mood] = [
        Mood(name: "Happy", emoji: "😊", color: .yellow, rating: 4.0),
        Mood(name: "Fulfilled", emoji: "🥰", color: .pink, rating: 5.0),
        Mood(name: "Peaceful", emoji: "😌", color: .mint, rating: 3.0),
        Mood(name: "Worried", emoji: "😟", color: .orange, rating: -2.0),
        Mood(name: "Sad", emoji: "😢", color: .blue, rating: -4.0),
        Mood(name: "Angry", emoji: "😠", color: .red, rating: -3.0),
        Mood(name: "Anxious", emoji: "😰", color: .purple, rating: -3.0),
        Mood(name: "Excited", emoji: "🤩", color: .yellow, rating: 4.5),
        Mood(name: "Tired", emoji: "😮‍💨", color: .gray, rating: -1.0),
        Mood(name: "Grateful", emoji: "🙏", color: .green, rating: 4.0)
    ]
    
    var allMoods: [Mood] {
        defaultMoods + customMoods
    }
    
    init(openAIApiKey: String) {
        self.openAIService = OpenAIService(apiKey: openAIApiKey)
        loadEntries()
        loadTags()
        loadCustomMoods()
        loadReflections()
        loadSuggestions()
    }
    
    func deleteEntry(_ entry: MoodEntry) {
        entries.removeAll { $0.id == entry.id }
        suggestions.removeValue(forKey: entry.id)
        saveEntries()
    }
    
    func saveEntry(date: Date, mood: Mood, notes: String, tags: [Tag]) {
        let entry = MoodEntry(date: date, mood: mood, notes: notes, tags: tags)
        entries.append(entry)
        saveEntries()
    }
    
    func addCustomMood(name: String, emoji: String, color: Color) {
        let newMood = Mood(name: name, emoji: emoji, color: color, rating: 0.0, isCustom: true)
        customMoods.append(newMood)
        saveCustomMoods()
    }
    
    func deleteCustomMood(_ mood: Mood) {
        customMoods.removeAll { $0.id == mood.id }
        saveCustomMoods()
    }
    
    func addTag(_ name: String) {
        let newTag = Tag(name: name)
        availableTags.append(newTag)
        saveTags()
    }
    
    private func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([MoodEntry].self, from: data) {
            entries = decoded
        }
    }
    
    private func saveTags() {
        if let encoded = try? JSONEncoder().encode(availableTags) {
            UserDefaults.standard.set(encoded, forKey: tagsKey)
        }
    }
    
    private func saveCustomMoods() {
        if let encoded = try? JSONEncoder().encode(customMoods) {
            UserDefaults.standard.set(encoded, forKey: customMoodsKey)
        }
    }
    
    private func loadCustomMoods() {
        if let data = UserDefaults.standard.data(forKey: customMoodsKey),
           let decoded = try? JSONDecoder().decode([Mood].self, from: data) {
            customMoods = decoded
        }
    }
    
    private func loadTags() {
        if let data = UserDefaults.standard.data(forKey: tagsKey),
           let decoded = try? JSONDecoder().decode([Tag].self, from: data) {
            availableTags = decoded
        }
    }
    
    func getSuggestion(for entry: MoodEntry) async {
        guard subscriptionManager.canAccessAIFeatures() else {
            suggestions[entry.id] = "⭐️ Upgrade to Premium to get AI-powered suggestions!"
            return
        }
        
        do {
            let suggestion = try await openAIService.getSuggestion(
                for: entry,
                previousEntries: entries.filter { $0.id != entry.id }
            )
            DispatchQueue.main.async {
                self.suggestions[entry.id] = suggestion
                self.saveSuggestions()
            }
        } catch {
            print("Error getting suggestion: \(error)")
            DispatchQueue.main.async {
                self.suggestions[entry.id] = "Unable to get suggestion. Please try again."
            }
        }
    }
    
    private func saveSuggestions() {
        if let encoded = try? JSONEncoder().encode(suggestions) {
            UserDefaults.standard.set(encoded, forKey: suggestionsKey)
        }
    }
    
    private func loadSuggestions() {
        if let data = UserDefaults.standard.data(forKey: suggestionsKey),
           let decoded = try? JSONDecoder().decode([UUID: String].self, from: data) {
            suggestions = decoded
        }
    }
    
    // Function to analyze tag correlations for a specific mood
    func getTagCorrelations(for mood: Mood, in timeframe: Timeframe) -> [(tag: Tag, count: Int)] {
        let filteredEntries = getFilteredEntries(for: timeframe)
        var tagCounts: [Tag: Int] = [:]
        
        // Count occurrences of tags for this specific mood
        for entry in filteredEntries where entry.mood.id == mood.id {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        
        return tagCounts.map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }
    
    // Helper function to get filtered entries for a timeframe
    func getFilteredEntries(for timeframe: Timeframe) -> [MoodEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        return entries.filter { entry in
            switch timeframe {
            case .week:
                return calendar.isDate(entry.date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(entry.date, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(entry.date, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    // Function to calculate average mood rating for a timeframe
    func getAverageMoodRating(for timeframe: Timeframe) -> Double {
        let filteredEntries = getFilteredEntries(for: timeframe)
        guard !filteredEntries.isEmpty else { return 0 }
        
        let totalRating = filteredEntries.reduce(0.0) { $0 + $1.mood.rating }
        return totalRating / Double(filteredEntries.count)
    }
    
    // Function to get mood distribution for a timeframe
    func getMoodDistribution(for timeframe: Timeframe) -> [(mood: Mood, count: Int)] {
        let filteredEntries = getFilteredEntries(for: timeframe)
        var distribution: [Mood: Int] = [:]
        
        for entry in filteredEntries {
            distribution[entry.mood, default: 0] += 1
        }
        
        return distribution.map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }
    
    func saveReflection(_ reflection: ReflectionEntry) {
        reflections.append(reflection)
        saveReflections()
    }
    
    private func saveReflections() {
        if let encoded = try? JSONEncoder().encode(reflections) {
            UserDefaults.standard.set(encoded, forKey: reflectionsKey)
        }
    }
    
    private func loadReflections() {
        if let data = UserDefaults.standard.data(forKey: reflectionsKey),
           let decoded = try? JSONDecoder().decode([ReflectionEntry].self, from: data) {
            reflections = decoded
        }
    }
    
    func getReflectionInsight(prompt: String) async throws -> String {
        guard subscriptionManager.canAccessAIFeatures() else {
            return "⭐️ Upgrade to Premium to get AI-powered reflection insights!"
        }
        
        return try await openAIService.getReflectionInsight(prompt: prompt)
    }
}

struct EntriesListView: View {
    @ObservedObject var moodStore: MoodStore
    
    var body: some View {
        ScrollView {
            if moodStore.entries.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 60))
                        .foregroundColor(.themeAccent.opacity(0.5))
                    Text("No entries yet")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: UIScreen.main.bounds.height - 200)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(moodStore.entries.sorted(by: { $0.date > $1.date })) { entry in
                        EntryCard(
                            entry: entry,
                            suggestion: moodStore.suggestions[entry.id],
                            onGetSuggestion: {
                                Task {
                                    await moodStore.getSuggestion(for: entry)
                                }
                            },
                            onDelete: {
                                moodStore.deleteEntry(entry)
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
        }
        .background(Color.themeBeige)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Journal")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.themeAccent)
            }
        }
    }
}

struct TimeframeGraphCard: View {
    let entries: [MoodEntry]
    let title: String
    let timeframe: Timeframe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.themeAccent)
            
            MoodTrendGraph(entries: entries, timeframe: timeframe)
                .frame(height: 150)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.themeBeigeDark)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct ReflectionView: View {
    @ObservedObject var moodStore: MoodStore
    let timeframe: Timeframe
    @State private var selectedPrompt: ReflectionPrompt?
    @State private var isShowingPromptSheet = false
    @State private var userReflection = ""
    
    var reflectionPrompts: [ReflectionPrompt] {
        let entries = moodStore.getFilteredEntries(for: timeframe)
        let avgRating = moodStore.getAverageMoodRating(for: timeframe)
        let distribution = moodStore.getMoodDistribution(for: timeframe)
        let mostFrequentMood = distribution.first?.mood
        
        var prompts = [
            ReflectionPrompt(
                question: "What patterns do you notice in your mood variations?",
                systemPrompt: "Analyze the user's mood patterns and provide insights about their emotional rhythms, suggesting potential factors that might influence these patterns."
            ),
            ReflectionPrompt(
                question: "What activities or situations seem to boost your mood?",
                systemPrompt: "Look at the positive mood entries and their associated tags to identify activities and situations that consistently correlate with better moods."
            ),
            ReflectionPrompt(
                question: "Are there specific times when your mood tends to dip?",
                systemPrompt: "Examine the lower-rated mood entries and their contexts to help identify potential triggers or patterns in mood decreases."
            )
        ]
        
        // Add dynamic prompts based on the data
        if let frequentMood = mostFrequentMood {
            prompts.append(
                ReflectionPrompt(
                    question: "You've been feeling \(frequentMood.name.lowercased()) quite often. What might be contributing to this?",
                    systemPrompt: "The user's most frequent mood is \(frequentMood.name). Help them explore the factors and circumstances around this prevalent emotion."
                )
            )
        }
        
        if avgRating < 0 {
            prompts.append(
                ReflectionPrompt(
                    question: "Your average mood has been on the lower side. What support or changes might help?",
                    systemPrompt: "The user's average mood rating is negative. Provide empathetic insights and suggest gentle ways to improve their emotional well-being."
                )
            )
        } else if avgRating > 3 {
            prompts.append(
                ReflectionPrompt(
                    question: "Your mood has been quite positive! What's been working well for you?",
                    systemPrompt: "The user's average mood rating is notably positive. Help them identify and reinforce the positive factors in their life."
                )
            )
        }
        
        return prompts
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reflection Prompts")
                .font(.headline)
                .foregroundColor(.themeAccent)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(reflectionPrompts) { prompt in
                        Button(action: {
                            selectedPrompt = prompt
                            isShowingPromptSheet = true
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text(prompt.question)
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .frame(width: 200)
                            .frame(maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.themeBeigeDark)
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.themeBeigeDark)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .sheet(isPresented: $isShowingPromptSheet) {
            if let prompt = selectedPrompt {
                NavigationView {
                    ZStack {
                        Color.themeBeige
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            Text(prompt.question)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            PlaceholderTextEditor(
                                placeholder: "Take a moment to pause and reflect. What thoughts, feelings, or insights come to mind? Your reflection can be as brief or detailed as you'd like...",
                                text: $userReflection,
                                height: 150
                            )
                            .padding(.horizontal)
                            
                            Button(action: {
                                Task {
                                    await getAIInsight(for: prompt)
                                }
                            }) {
                                Label("Get AI Insight", systemImage: "sparkles")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.themeAccent)
                                    )
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                            
                            if let response = prompt.response {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AI Insight")
                                        .font(.headline)
                                        .foregroundColor(.themeAccent)
                                    Text(response)
                                        .font(.body)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.themeBeigeDark)
                                )
                                .padding(.horizontal)
                            }
                            
                            Spacer()
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                isShowingPromptSheet = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    func getAIInsight(for prompt: ReflectionPrompt) async {
        let recentEntries = moodStore.entries.suffix(5)
        let entriesContext = recentEntries.map { entry in
            """
            Date: \(entry.date.formatted())
            Mood: \(entry.mood.name) (\(entry.mood.emoji)) - Rating: \(entry.mood.rating)
            Tags: \(entry.tags.map { $0.name }.joined(separator: ", "))
            """
        }.joined(separator: "\n\n")
        
        let fullPrompt = """
        \(prompt.systemPrompt)
        
        Recent entries:
        \(entriesContext)
        
        User's reflection:
        \(userReflection)
        
        Provide a brief, empathetic response that:
        1. Acknowledges their feelings
        2. Offers one key insight
        3. Suggests one small, actionable step
        
        Keep the response concise and supportive.
        """
        
        do {
            let insight = try await moodStore.openAIService.getReflectionInsight(prompt: fullPrompt)
            selectedPrompt?.response = insight
        } catch {
            selectedPrompt?.response = "Unable to generate insight at this time. Please try again later."
        }
    }
}

struct MoodRatingScale: View {
    let rating: Double
    
    var moodDescription: String {
        switch rating {
        case 4...: return "Very Positive"
        case 2..<4: return "Positive"
        case 0..<2: return "Slightly Positive"
        case -2..<0: return "Slightly Negative"
        case -4..<(-2): return "Negative"
        default: return "Very Negative"
        }
    }
    
    var moodColor: Color {
        switch rating {
        case 4...: return .green
        case 2..<4: return .mint
        case 0..<2: return .blue
        case -2..<0: return .orange
        case -4..<(-2): return .red
        default: return .purple
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Scale visualization
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(moodColor)
                    .frame(width: CGFloat((rating + 5) / 10) * 200, height: 8)
            }
            .frame(width: 200)
            
            // Scale labels
            HStack {
                Text("-5")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text("0")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text("+5")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 200)
        }
    }
}

struct TimeframeInsightView: View {
    @ObservedObject var moodStore: MoodStore
    let timeframe: Timeframe
    
    var entries: [MoodEntry] {
        moodStore.getFilteredEntries(for: timeframe)
    }
    
    var averageRating: Double {
        moodStore.getAverageMoodRating(for: timeframe)
    }
    
    var distribution: [(mood: Mood, count: Int)] {
        moodStore.getMoodDistribution(for: timeframe)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) { // Increased spacing between main sections
                // Graph Section
                VStack(alignment: .leading, spacing: 16) { // Increased internal spacing
                    Text("Mood Trend")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.themeAccent)
                    
                    MoodTrendGraph(entries: entries, timeframe: timeframe)
                        .frame(height: 200)
                }
                .padding(20) // Increased padding
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.themeBeigeDark)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                // Summary Card
                VStack(alignment: .leading, spacing: 24) { // Increased spacing between sections
                    Text("Summary")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.themeAccent)
                    
                    // Average Mood Section
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Average Mood")
                                .font(.headline)
                                .foregroundColor(.themeAccent)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(String(format: "%.1f", averageRating))
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.black)
                                Text(getMoodDescription(for: averageRating))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        MoodRatingScale(rating: averageRating)
                            .padding(.vertical, 8)
                        
                        Text("Mood Scale: -5 (most negative) to +5 (most positive)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Statistics Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Statistics")
                            .font(.headline)
                            .foregroundColor(.themeAccent)
                        
                        HStack(spacing: 40) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total Entries")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("\(entries.count)")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            
                            if !entries.isEmpty, let mostCommon = distribution.first {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Most Common")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    HStack(spacing: 8) {
                                        Text(mostCommon.mood.emoji)
                                            .font(.system(size: 24))
                                        Text(mostCommon.mood.name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(24) // Increased padding
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.themeBeigeDark)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                // Mood Distribution
                VStack(alignment: .leading, spacing: 20) { // Increased spacing
                    Text("Mood Analysis")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.themeAccent)
                        .padding(.horizontal)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) { // Increased spacing between mood items
                            ForEach(distribution, id: \.mood.id) { item in
                                VStack(alignment: .leading, spacing: 12) { // Increased internal spacing
                                    HStack {
                                        Text(item.mood.emoji)
                                            .font(.system(size: 32))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.mood.name)
                                                .font(.headline)
                                            Text("Rating: \(String(format: "%.1f", item.mood.rating))")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text("\(item.count)")
                                            .font(.title2)
                                            .foregroundColor(.themeAccent)
                                    }
                                    
                                    let tagCorrelations = moodStore.getTagCorrelations(for: item.mood, in: timeframe)
                                    if !tagCorrelations.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Common tags:")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(tagCorrelations.prefix(3), id: \.tag.id) { tagItem in
                                                        HStack {
                                                            Text(tagItem.tag.name)
                                                            Text("(\(tagItem.count))")
                                                                .foregroundColor(.gray)
                                                        }
                                                        .font(.subheadline)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(
                                                            Capsule()
                                                                .fill(Color.themeAccent.opacity(0.15))
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.themeBeigeDark)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 24)
        }
    }
    
    private func getMoodDescription(for rating: Double) -> String {
        switch rating {
        case 4...: return "Very Positive"
        case 2..<4: return "Positive"
        case 0..<2: return "Slightly Positive"
        case -2..<0: return "Slightly Negative"
        case -4..<(-2): return "Negative"
        default: return "Very Negative"
        }
    }
}

struct InsightsView: View {
    @ObservedObject var moodStore: MoodStore
    @State private var selectedTimeframe: Timeframe = .week
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Timeframe Picker
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected timeframe
                TimeframeInsightView(moodStore: moodStore, timeframe: selectedTimeframe)
            }
            .padding(.vertical, 16)
        }
        .background(Color.themeBeige)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Insights")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.themeAccent)
            }
        }
    }
}

struct MoodTrendGraph: View {
    let entries: [MoodEntry]
    let timeframe: Timeframe
    private let calendar = Calendar.current
    
    private var dataPoints: [MoodDataPoint] {
        let sortedEntries = entries.sorted { $0.date < $1.date }
        
        // Group entries by time period based on timeframe
        var groupedEntries: [String: [MoodEntry]] = [:]
        
        for entry in sortedEntries {
            let key = getTimeframeKey(for: entry.date, timeframe: timeframe)
            if groupedEntries[key] == nil {
                groupedEntries[key] = []
            }
            groupedEntries[key]?.append(entry)
        }
        
        // Convert grouped entries to data points with averaged ratings
        let dataPoints = groupedEntries.compactMap { (key, entriesInPeriod) -> MoodDataPoint? in
            guard let firstEntry = entriesInPeriod.first else { return nil }
            
            // Calculate average rating for this time period
            let averageRating = entriesInPeriod.reduce(0.0) { $0 + $1.mood.rating } / Double(entriesInPeriod.count)
            
            return MoodDataPoint(date: firstEntry.date, value: averageRating)
        }
        
        // Sort by date and return
        return dataPoints.sorted { $0.date < $1.date }
    }
    
    private func getTimeframeKey(for date: Date, timeframe: Timeframe) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .year:
            // Group by month within the year
            formatter.dateFormat = "yyyy-MM"
        case .month:
            // Group by day within the month
            formatter.dateFormat = "yyyy-MM-dd"
        case .week:
            // Group by day within the week
            formatter.dateFormat = "yyyy-MM-dd"
        }
        
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dataPoints.isEmpty {
                Text("No data yet")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height - 20 // Reserve space for dates
                    let maxValue = 5.0
                    let minValue = -5.0
                    
                    VStack(spacing: 4) {
                        // Graph
                        ZStack {
                            // Grid lines
                            VStack(spacing: height / 10) {
                                ForEach(0..<11) { i in
                                    Divider()
                                        .background(Color.gray.opacity(0.2))
                                }
                            }
                            
                            // Zero line
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                                .offset(y: height / 2)
                            
                            // Line graph
                            Path { path in
                                for (index, point) in dataPoints.enumerated() {
                                    let x = width * CGFloat(index) / CGFloat(max(1, dataPoints.count - 1))
                                    let y = height * (1 - CGFloat((point.value - minValue) / (maxValue - minValue)))
                                    
                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.themeAccent, .themeAccentLight]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                            )
                            
                            // Data points
                            ForEach(dataPoints.indices, id: \.self) { index in
                                let point = dataPoints[index]
                                let x = width * CGFloat(index) / CGFloat(max(1, dataPoints.count - 1))
                                let y = height * (1 - CGFloat((point.value - minValue) / (maxValue - minValue)))
                                
                                Circle()
                                    .fill(Color.themeAccent)
                                    .frame(width: 6, height: 6)
                                    .position(x: x, y: y)
                            }
                        }
                        
                        // Date labels - formatted based on timeframe
                        HStack {
                            ForEach(dataPoints.indices, id: \.self) { index in
                                if index % 2 == 0 || index == dataPoints.count - 1 {
                                    Text(formatDateForTimeframe(dataPoints[index].date, timeframe: timeframe))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func formatDateForTimeframe(_ date: Date, timeframe: Timeframe) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .year:
            // Year view: show only month names (Jan, Feb, etc.)
            formatter.dateFormat = "MMM"
        case .month:
            // Month view: show only day numbers (1, 2, 3, etc.)
            formatter.dateFormat = "d"
        case .week:
            // Week view: show day abbreviations (Mon, Tue, etc.)
            formatter.dateFormat = "E"
        }
        
        return formatter.string(from: date)
    }
}

struct ContentView: View {
    @StateObject private var moodStore: MoodStore
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingSubscription = false
    
    init() {
        // Get API key from secure configuration
        let apiKey = Config.getOpenAIAPIKey()
        _moodStore = StateObject(wrappedValue: MoodStore(openAIApiKey: apiKey))
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.themeBeige)
        appearance.shadowColor = .clear
        
        // Apply to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var upgradeButton: some View {
        Button(action: {
            showingSubscription = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text(subscriptionManager.currentSubscriptionTier == .premium ? "Premium" : "Upgrade")
            }
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.themeAccent)
            )
        }
        #if DEBUG
        .contextMenu {
            if subscriptionManager.currentSubscriptionTier == .premium {
                Button(role: .destructive, action: {
                    subscriptionManager.debugUnsubscribe()
                }) {
                    Label("Debug: Unsubscribe", systemImage: "xmark.circle")
                }
            }
        }
        #endif
    }
    
    var body: some View {
        TabView {
            NavigationView {
                MoodTrackerView(moodStore: moodStore)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            upgradeButton
                        }
                        ToolbarItem(placement: .principal) {
                            Text("EmberNote")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.themeAccent)
                        }
                    }
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("New Entry", systemImage: "plus.circle.fill")
            }
            
            NavigationView {
                EntriesListView(moodStore: moodStore)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            upgradeButton
                        }
                    }
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Journal", systemImage: "book.fill")
            }
            
            NavigationView {
                InsightsView(moodStore: moodStore)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            upgradeButton
                        }
                    }
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Insights", systemImage: "chart.bar.fill")
            }
            
            NavigationView {
                ReflectionsView(moodStore: moodStore)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            upgradeButton
                        }
                    }
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Reflect", systemImage: "lightbulb.fill")
            }
        }
        .tint(.themeAccent)
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
    }
}

struct SavedReflectionCard: View {
    let reflection: ReflectionEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.themeAccent)
                Text(reflection.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
            
            Text(reflection.prompt)
                .font(.headline)
                .foregroundColor(.themeAccent)
            
            Text("Your Reflection:")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(reflection.reflection)
                .font(.body)
            
            if !reflection.aiResponse.isEmpty {
                Text("AI Insight:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(reflection.aiResponse)
                    .font(.body)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.themeBeigeDark)
        )
    }
}

struct ReflectionsView: View {
    @ObservedObject var moodStore: MoodStore
    @State private var showingNewReflection = false
    
    var body: some View {
        ScrollView {
            if moodStore.reflections.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 60))
                        .foregroundColor(.themeAccent.opacity(0.5))
                    Text("No reflections yet")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Button(action: {
                        showingNewReflection = true
                    }) {
                        Text("Start Reflecting")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.themeAccent)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: UIScreen.main.bounds.height - 200)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(moodStore.reflections.sorted(by: { $0.date > $1.date })) { reflection in
                        SavedReflectionCard(reflection: reflection)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
        }
        .background(Color.themeBeige)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Reflections")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.themeAccent)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingNewReflection = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.themeAccent)
                }
            }
        }
        .sheet(isPresented: $showingNewReflection) {
            ReflectionPromptView(moodStore: moodStore)
        }
    }
}

struct ReflectionPromptView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var moodStore: MoodStore
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPrompt: ReflectionPrompt?
    @State private var userReflection = ""
    @State private var aiResponse: String?
    @State private var isGeneratingResponse = false
    
    // Separate general and AI prompts
    var generalPrompts: [ReflectionPrompt] {
        [
            ReflectionPrompt(
                question: "Think about a moment today that made you smile. What was special about it?",
                systemPrompt: "Help the user explore positive experiences and identify what brings them joy."
            ),
            ReflectionPrompt(
                question: "When you felt most at peace today, what was happening around you?",
                systemPrompt: "Guide the user in recognizing their sources of calm and contentment."
            ),
            ReflectionPrompt(
                question: "Name three small things you're grateful for right now. Why do they matter to you?",
                systemPrompt: "Help the user practice gratitude and explore the deeper meaning behind everyday positives."
            )
        ]
    }
    
    var aiPrompts: [ReflectionPrompt] {
        let recentEntries = moodStore.entries.suffix(10) // Increased from 5 to get more data
        let avgRating = recentEntries.isEmpty ? 0 : recentEntries.map { $0.mood.rating }.reduce(0, +) / Double(recentEntries.count)
        let moodCounts = recentEntries.reduce(into: [:]) { counts, entry in
            counts[entry.mood.name, default: 0] += 1
        }
        let mostFrequentMood = moodCounts.max(by: { $0.value < $1.value })?.key
        
        var prompts: [ReflectionPrompt] = []
        
        // Always add some base AI prompts
            prompts.append(contentsOf: [
                ReflectionPrompt(
                question: "What patterns do you notice in your recent moods?",
                systemPrompt: "Help the user identify patterns in their emotional experiences."
                ),
                ReflectionPrompt(
                question: "What activities or situations tend to boost your mood?",
                systemPrompt: "Guide the user to recognize positive influences in their life."
            )
        ])
        
        // Add conditional prompts based on data
        if avgRating < 0 {
            prompts.append(
                ReflectionPrompt(
                    question: "If you could send a kind message to yourself right now, what would you say?",
                    systemPrompt: "Guide the user in practicing self-compassion during challenging times."
                )
            )
        } else if avgRating > 2 {
            prompts.append(
                ReflectionPrompt(
                    question: "Your mood has been quite positive! What's been working well for you?",
                    systemPrompt: "Help the user identify and reinforce positive patterns in their life."
                )
            )
        }
        
        if let frequentMood = mostFrequentMood {
            if frequentMood.contains("Happy") || frequentMood.contains("Excited") || frequentMood.contains("Grateful") {
                prompts.append(
                    ReflectionPrompt(
                        question: "You've been feeling \(frequentMood.lowercased()) often. What positive changes would you like to maintain?",
                        systemPrompt: "Help the user identify and reinforce positive patterns in their life."
                    )
                )
            } else if frequentMood.contains("Anxious") || frequentMood.contains("Worried") || frequentMood.contains("Sad") {
                prompts.append(
                    ReflectionPrompt(
                        question: "You've been feeling \(frequentMood.lowercased()) lately. What small comfort activities help you feel better?",
                        systemPrompt: "Guide the user in developing practical coping strategies."
                    )
                )
            }
        }
        
        return prompts
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.themeBeige.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose a Reflection Prompt")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.themeAccent)
                            Text("Select a prompt below to begin your reflection...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        
                        // General Prompts Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("General Prompts")
                                .font(.headline)
                                .foregroundColor(.themeAccent)
                                .padding(.horizontal)
                            
                            ForEach(generalPrompts) { prompt in
                                Button(action: { selectedPrompt = prompt }) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                                        Text(prompt.question)
                                            .font(.body)
                                            .foregroundColor(.black)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.themeBeigeDark))
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Suggested Prompts Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Suggested Prompts")
                                .font(.headline)
                                .foregroundColor(.themeAccent)
                                .padding(.horizontal)
                            
                            if subscriptionManager.canAccessAIFeatures() {
                                ForEach(aiPrompts) { prompt in
                                    Button(action: { selectedPrompt = prompt }) {
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "sparkles").foregroundColor(.themeAccent)
                                            Text(prompt.question)
                                                .font(.body)
                                                .foregroundColor(.black)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.themeBeigeDark))
                                    }
                                    .padding(.horizontal)
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill").foregroundColor(.gray)
                                    Text("Upgrade to Premium to unlock AI-powered suggested prompts.")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.themeBeigeDark))
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: .constant(selectedPrompt != nil)) {
            if let prompt = selectedPrompt {
                NavigationView {
                    ZStack {
                        Color.themeBeige.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                            Text(prompt.question)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.themeAccent)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            PlaceholderTextEditor(
                                placeholder: "Take a moment to pause and reflect. What thoughts, feelings, or insights come to mind? Your reflection can be as brief or detailed as you'd like...",
                                text: $userReflection,
                                height: 200
                            )
                            .padding(.horizontal)
                            
                            // Action Buttons
                                if subscriptionManager.canAccessAIFeatures() {
                            VStack(spacing: 16) {
                                Button(action: {
                                    Task {
                                        isGeneratingResponse = true
                                        await getAIInsight(for: prompt)
                                        isGeneratingResponse = false
                                    }
                                }) {
                                    HStack {
                                        if isGeneratingResponse {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .padding(.trailing, 8)
                                        }
                                        Label(
                                            isGeneratingResponse ? "Generating..." : "Get AI Insight",
                                            systemImage: "sparkles"
                                        )
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.themeAccent)
                                    )
                                    .foregroundColor(.white)
                                }
                                .disabled(userReflection.isEmpty || isGeneratingResponse)
                                .opacity((userReflection.isEmpty || isGeneratingResponse) ? 0.6 : 1.0)
                            }
                            .padding(.horizontal)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock.fill").foregroundColor(.gray)
                                        Text("Upgrade to Premium to unlock AI-powered insights.")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.themeBeigeDark))
                                    .padding(.horizontal)
                                }
                            
                                if let response = aiResponse, subscriptionManager.canAccessAIFeatures() {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("AI Insight")
                                        .font(.headline)
                                        .foregroundColor(.themeAccent)
                                    Text(response)
                                        .font(.body)
                                        .lineSpacing(4)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.themeBeigeDark)
                                )
                                .padding(.horizontal)
                            }
                            
                            // Save Options
                            VStack(spacing: 16) {
                                    if aiResponse != nil && subscriptionManager.canAccessAIFeatures() {
                                    Button(action: {
                                        saveReflection(prompt: prompt.question, response: aiResponse)
                                            selectedPrompt = nil
                                            userReflection = ""
                                            aiResponse = nil
                                        dismiss()
                                    }) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.down.fill")
                                            Text("Save Reflection with AI Insight")
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.green)
                                        )
                                        .foregroundColor(.white)
                                    }
                                }
                                
                                Button(action: {
                                        saveReflection(prompt: prompt.question, response: nil)
                                        selectedPrompt = nil
                                        userReflection = ""
                                        aiResponse = nil
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Save Reflection Only")
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.themeAccentLight)
                                    )
                                    .foregroundColor(.white)
                                }
                            }
                            .disabled(userReflection.isEmpty)
                            .opacity(userReflection.isEmpty ? 0.6 : 1.0)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
                    .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") {
                            selectedPrompt = nil
                            userReflection = ""
                            aiResponse = nil
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                                selectedPrompt = nil
                                userReflection = ""
                                aiResponse = nil
                        dismiss()
                            }
                        }
                    }
                    }
                }
            }
        }
    }
    
// Add back the missing functions
extension ReflectionPromptView {
    func getAIInsight(for prompt: ReflectionPrompt) async {
        guard subscriptionManager.canAccessAIFeatures() else {
            aiResponse = "⭐️ Upgrade to Premium to get AI-powered reflection insights!"
            return
        }
        
        let recentEntries = moodStore.entries.suffix(5)
        let entriesContext = recentEntries.map { entry in
            """
            Date: \(entry.date.formatted())
            Mood: \(entry.mood.name) (\(entry.mood.emoji)) - Rating: \(entry.mood.rating)
            Tags: \(entry.tags.map { $0.name }.joined(separator: ", "))
            """
        }.joined(separator: "\n\n")
        
        let fullPrompt = """
        \(prompt.systemPrompt)
        
        Recent entries:
        \(entriesContext)
        
        User's reflection:
        \(userReflection)
        
        Provide a brief, empathetic response that:
        1. Acknowledges their feelings
        2. Offers one key insight
        3. Suggests one small, actionable step
        
        Keep the response concise and supportive.
        """
        
        do {
            let insight = try await moodStore.getReflectionInsight(prompt: fullPrompt)
            aiResponse = insight
        } catch {
            aiResponse = "Unable to generate insight at this time. Please try again later."
        }
    }
    
    func saveReflection(prompt: String, response: String?) {
        let reflection = ReflectionEntry(
            prompt: prompt,
            reflection: userReflection,
            aiResponse: response ?? "" // When saving reflection only, response will be nil
        )
        moodStore.saveReflection(reflection)
    }
}

struct EntryCard: View {
    let entry: MoodEntry
    let suggestion: String?
    let onGetSuggestion: () -> Void
    let onDelete: () -> Void
    @State private var showingSuggestion = false
    @State private var showingDeleteAlert = false
    @State private var hasGeneratedSuggestion = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    private var isUpgradeMessage: Bool {
        suggestion?.contains("⭐️ Upgrade to Premium") == true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with emoji, date and actions
            HStack(alignment: .center, spacing: 12) {
                Text(entry.mood.emoji)
                    .font(.system(size: 44))
                
                VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .date)
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(entry.mood.name)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    if suggestion == nil || (isUpgradeMessage && subscriptionManager.currentSubscriptionTier == .premium) {
                        Button(action: {
                            onGetSuggestion()
                            hasGeneratedSuggestion = true
                            showingSuggestion = true
                        }) {
                            Image(systemName: "lightbulb")
                                .font(.title2)
                        .foregroundColor(.themeAccent)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.themeAccent.opacity(0.1))
                                )
                        }
                    }
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
            }
            
            // Tags Section
            if !entry.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.tags) { tag in
                            Text(tag.name)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.themeAccent.opacity(0.15))
                                )
                                .foregroundColor(.themeAccent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Notes Section
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.vertical, 4)
            }
            
            // AI Suggestion Section
            if let suggestion = suggestion {
                    Divider()
                    .padding(.vertical, 4)
                
                DisclosureGroup(
                    isExpanded: $showingSuggestion,
                    content: {
                    Text(suggestion)
                        .font(.body)
                        .foregroundColor(.gray)
                            .lineSpacing(4)
                            .padding(.top, 12)
                    },
                    label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("AI Insight")
                                .font(.headline)
                                .foregroundColor(.themeAccent)
                        }
                    }
                )
                .onChange(of: hasGeneratedSuggestion) { oldValue, newValue in
                    if newValue {
                        showingSuggestion = true
                        hasGeneratedSuggestion = false
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.themeBeigeDark)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
        .onDisappear {
            showingSuggestion = false
        }
    }
}

struct CalendarView: View {
    @Binding var selectedDate: Date
    let entries: [MoodEntry]
    @State private var currentMonth: Date
    @GestureState private var dragOffset: CGFloat = 0
    
    private let calendar = Calendar.current
    private let daysInWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    init(selectedDate: Binding<Date>, entries: [MoodEntry]) {
        self._selectedDate = selectedDate
        self.entries = entries
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack {
            // Month and Year header with navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.themeAccent)
                }
                
                Spacer()
                
                Text(currentMonth, format: .dateTime.month(.wide))
                    .font(.title2.bold())
                    .onTapGesture {
                        withAnimation {
                            currentMonth = Date()
                        }
                    }
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.themeAccent)
                }
            }
            .padding(.horizontal)
            
            // Days of week header
            HStack {
                ForEach(daysInWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // Calendar grid
            let days = getDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            hasEntry: hasEntry(for: date),
                            moodColor: getMoodColor(for: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold {
                        withAnimation {
                            previousMonth()
                        }
                    } else if value.translation.width < -threshold {
                        withAnimation {
                            nextMonth()
                        }
                    }
                }
        )
    }
    
    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func getDaysInMonth() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: currentMonth)!
        let firstDay = interval.start
        
        // Get the first weekday of the month (0 = Sunday, 6 = Saturday)
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        
        // Create array with empty cells for days before the first of the month
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        // Add all days of the month
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!.count
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func hasEntry(for date: Date) -> Bool {
        entries.contains { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }
    
    private func getMoodColor(for date: Date) -> Color? {
        entries.first { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }?.mood.color
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasEntry: Bool
    let moodColor: Color?
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16))
                .frame(minWidth: 32, minHeight: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.themeAccent.opacity(0.2) : Color.clear)
                )
            
            if hasEntry {
                Circle()
                    .fill(moodColor ?? .themeAccent)
                    .frame(width: 6, height: 6)
            } else {
                Color.clear
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MoodSelectionView: View {
    let moods: [Mood]
    @Binding var selectedMood: Mood?
    let onManageMoods: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
                ForEach(moods) { mood in
                    VStack(spacing: 8) {
                Button(action: {
                    withAnimation(.spring()) {
                        selectedMood = mood
                    }
                }) {
                    Text(mood.emoji)
                                .font(.system(size: 32))
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                        .fill(mood.color.opacity(selectedMood?.id == mood.id ? 0.3 : 0.15))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(mood.color.opacity(0.3), lineWidth: selectedMood?.id == mood.id ? 2 : 0)
                                )
                                .scaleEffect(selectedMood?.id == mood.id ? 1.1 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                        
                            Text(mood.name)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .frame(maxWidth: 60)
                    }
                    .frame(height: 82)
                }
                
                // Manage Moods Button
                VStack(spacing: 8) {
                    Button(action: onManageMoods) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(Color.themeAccent.opacity(0.15))
                            )
                            .foregroundColor(.themeAccent)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Manage")
                        .font(.caption)
                        .foregroundColor(.themeAccent)
                        .lineLimit(1)
                        .frame(maxWidth: 60)
                }
                .frame(height: 82)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

struct NotesSection: View {
    @Binding var notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.title3)
                .bold()
            PlaceholderTextEditor(
                placeholder: "What's on your mind? Add any thoughts or experiences you'd like to remember...",
                text: $notes,
                height: 120
                )
        }
        .padding(.horizontal)
    }
}

struct SaveButton: View {
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Save")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.themeAccent, .themeAccentLight]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .themeAccent.opacity(0.3), radius: 5, x: 0, y: 3)
                )
                .foregroundColor(.white)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct ManageMoodsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var moodStore: MoodStore
    @State private var showingAddMoodSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.themeBeige
                    .ignoresSafeArea()
                
                List {
                    Section(header: Text("Default Moods").customSectionHeader()) {
                        ForEach(moodStore.defaultMoods) { mood in
                            HStack {
                                Text(mood.emoji)
                                    .font(.title2)
                                Text(mood.name)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    
                    Section(header: Text("Custom Moods").customSectionHeader()) {
                        ForEach(moodStore.customMoods) { mood in
                            HStack {
                                Text(mood.emoji)
                                    .font(.title2)
                                Text(mood.name)
                                    .foregroundColor(.black)
                                Spacer()
                                Button(action: {
                                    moodStore.deleteCustomMood(mood)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        Button(action: {
                            showingAddMoodSheet = true
                        }) {
                            Label("Add Custom Mood", systemImage: "plus.circle.fill")
                                .foregroundColor(.themeAccent)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.themeBeige)
                .dismissKeyboardOnTap()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Manage Moods")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.themeAccent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.themeAccent)
                }
            }
            .sheet(isPresented: $showingAddMoodSheet) {
                CustomMoodView(moodStore: moodStore)
            }
        }
    }
}

struct CustomMoodView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var moodStore: MoodStore
    @State private var name = ""
    @State private var emoji = ""
    @State private var selectedColor = Color.purple
    @State private var currentEmojiPage = 0
    
    let categories = ["😊", "😋", "😐", "😢", "❤️", "✨"]
    let categoryNames = ["Happy", "Fun", "Neutral", "Sad", "Love", "More"]
    
    let colors: [Color] = [
        // Warm Colors
        .red, .orange, .yellow,
        Color(red: 1.0, green: 0.4, blue: 0.4), // Coral
        Color(red: 1.0, green: 0.6, blue: 0.2), // Light Orange
        Color(red: 0.8, green: 0.2, blue: 0.2), // Dark Red
        
        // Cool Colors
        .blue, .mint, .cyan,
        Color(red: 0.2, green: 0.4, blue: 0.8), // Royal Blue
        Color(red: 0.0, green: 0.5, blue: 0.5), // Teal
        Color(red: 0.4, green: 0.7, blue: 1.0), // Light Blue
        
        // Purple & Pink Tones
        .purple, .pink, .indigo,
        Color(red: 0.8, green: 0.2, blue: 0.8), // Magenta
        Color(red: 0.6, green: 0.2, blue: 0.6), // Dark Purple
        Color(red: 1.0, green: 0.6, blue: 0.8), // Light Pink
        
        // Earth Tones
        .brown,
        Color(red: 0.6, green: 0.4, blue: 0.2), // Dark Brown
        Color(red: 0.8, green: 0.7, blue: 0.6), // Beige
        
        // Neutral Tones
        .gray,
        Color(red: 0.3, green: 0.3, blue: 0.3), // Dark Gray
        Color(red: 0.8, green: 0.8, blue: 0.8), // Light Gray
        
        // Nature Colors
        .green,
        Color(red: 0.2, green: 0.6, blue: 0.2), // Forest Green
        Color(red: 0.6, green: 0.8, blue: 0.2)  // Lime Green
    ]
    
    let emojiPages = [
        // Face-smiling
        ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "☺️", "😚"],
        // Face-playful
        ["😙", "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🫢", "🫣", "🤫", "🤔", "🫡", "🤤", "🤠", "🥳", "🥸", "🤓"],
        // Face-neutral
        ["😐", "😑", "😶", "🫥", "😶‍🌫️", "😏", "😒", "🙄", "😬", "😮‍💨", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢"],
        // Face-concerned
        ["😕", "🙁", "☹️", "😮", "😯", "😲", "😳", "🥺", "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓"],
        // Hearts & Hands
        ["❤️", "🧡", "💛", "💚", "💙", "💜", "🤎", "🤍", "💔", "❤️‍🩹", "❤️‍🩹", "🙏", "🤝", "👐", "🤲", "🫂", "💪", "🫀", "💫"],
        // Face-other
        ["😩", "😫", "🥱", "😤", "😡", "😠", "🤬", "😈", "👿", "💀", "☠️", "💩", "🤡", "👹", "👺", "👻", "👽", "👾", "🤖", "😺"]
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.themeBeige
                    .ignoresSafeArea()
                
                Form {
                    Section(header: Text("Mood Name").customSectionHeader()) {
                        TextField("What would you like to call this mood?", text: $name)
                            .foregroundColor(.black)
                    }
                    
                    Section(header: Text("Choose Emoji").customSectionHeader()) {
                        // Preview of selected emoji with color
                        if !emoji.isEmpty {
                            HStack {
                                Spacer()
                                Text(emoji)
                                    .font(.system(size: 60))
                                    .padding(20)
                                    .background(
                                        Circle()
                                            .fill(selectedColor.opacity(0.2))
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor, lineWidth: 2)
                                    )
                                Spacer()
                            }
                            .padding(.vertical)
                        }
                        
                        HStack(spacing: 0) {
                            ForEach(0..<categories.count, id: \.self) { index in
                                VStack(spacing: 4) {
                                    Text(categories[index])
                                        .font(.system(size: 20))
                                    Text(categoryNames[index])
                                        .font(.system(size: 10))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(currentEmojiPage == index ? 
                                            selectedColor.opacity(0.2) : 
                                            Color.clear)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        currentEmojiPage = index
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                            ForEach(emojiPages[currentEmojiPage], id: \.self) { emojiOption in
                                Text(emojiOption)
                                    .font(.system(size: 30))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(emoji == emojiOption ? 
                                                selectedColor.opacity(0.2) : 
                                                Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(emoji == emojiOption ? 
                                                selectedColor : Color.clear, 
                                                lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        emoji = emojiOption
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("Color").customSectionHeader()) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 35, height: 35)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: selectedColor == color ? 2 : 0)
                                    )
                                    .shadow(color: color.opacity(0.3), 
                                           radius: selectedColor == color ? 4 : 0)
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.themeBeige)
                .dismissKeyboardOnTap()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Mood")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.themeAccent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.themeAccent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if !name.isEmpty && !emoji.isEmpty {
                            moodStore.addCustomMood(
                                name: name,
                                emoji: emoji,
                                color: selectedColor
                            )
                            dismiss()
                        }
                    }
                    .font(.system(.body, design: .rounded))
                    .disabled(name.isEmpty || emoji.isEmpty)
                    .foregroundColor(name.isEmpty || emoji.isEmpty ? .gray : .themeAccent)
                }
            }
        }
    }
}

struct MoodTrackerView: View {
    @ObservedObject var moodStore: MoodStore
    @State private var selectedDate = Date()
    @State private var selectedMood: Mood? = nil
    @State private var notes = ""
    @State private var showingSaveAlert = false
    @State private var selectedTags: Set<Tag> = []
    @State private var showingAddTagAlert = false
    @State private var showingManageMoodsSheet = false
    @State private var newTagName = ""

    var body: some View {
                ScrollView {
            VStack(spacing: 32) {
                // Calendar Section
                VStack(spacing: 16) {
                        CalendarView(selectedDate: $selectedDate, entries: moodStore.entries)
                        .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.themeBeigeDark)
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                            )
                }
                            .padding(.horizontal)

                // Mood Selection Section
                VStack(spacing: 20) {
                    Text("How are you feeling?")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                            .foregroundColor(.themeAccent)

                    MoodSelectionView(
                        moods: moodStore.allMoods,
                        selectedMood: $selectedMood,
                        onManageMoods: { showingManageMoodsSheet = true }
                    )
                }

                        // Tags Section
                VStack(alignment: .leading, spacing: 16) {
                            Text("Tags")
                        .font(.title3)
                        .fontWeight(.semibold)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                                    ForEach(moodStore.availableTags) { tag in
                                        TagButton(
                                            tag: tag,
                                            isSelected: selectedTags.contains(tag),
                                            action: {
                                                withAnimation(.spring()) {
                                                    if selectedTags.contains(tag) {
                                                        selectedTags.remove(tag)
                                                    } else {
                                                        selectedTags.insert(tag)
                                                    }
                                                }
                                            }
                                        )
                                    }
                                    
                                    Button(action: {
                                        showingAddTagAlert = true
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.themeAccent)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(Color.themeAccent.opacity(0.1))
                                    )
                                    }
                                }
                                .padding(.horizontal)
                        .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal)

                // Notes Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notes")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    PlaceholderTextEditor(
                        placeholder: "What's on your mind? How are you feeling today? Add any thoughts or experiences you'd like to remember...",
                        text: $notes,
                        height: 150
                    )
                }
                .padding(.horizontal)

                        // Save Button
                        SaveButton(isEnabled: selectedMood != nil) {
                            if let mood = selectedMood {
                                withAnimation {
                                    moodStore.saveEntry(
                                        date: selectedDate,
                                        mood: mood,
                                        notes: notes,
                                        tags: Array(selectedTags)
                                    )
                                    selectedMood = nil
                                    notes = ""
                                    selectedTags.removeAll()
                                    showingSaveAlert = true
                                }
                            }
                        }
                .padding(.bottom, 24)
            }
            .padding(.vertical, 16)
        }
        .background(Color.themeBeige)
        .dismissKeyboardOnTap()
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("EmberNote")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.themeAccent)
            }
        }
            .alert("Entry Saved", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("Add New Tag", isPresented: $showingAddTagAlert) {
                TextField("Tag name", text: $newTagName)
                Button("Cancel", role: .cancel) {
                    newTagName = ""
                }
                Button("Add") {
                    if !newTagName.isEmpty {
                        moodStore.addTag(newTagName)
                        newTagName = ""
                    }
                }
            }
        .sheet(isPresented: $showingManageMoodsSheet) {
            ManageMoodsView(moodStore: moodStore)
        }
    }
}

struct TagButton: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag.name)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.themeAccent.opacity(0.2) : Color.themeAccentLight.opacity(0.1))
                )
                .foregroundColor(isSelected ? .themeAccent : .primary)
        }
    }
}

#Preview {
    ContentView()
}

// Add this extension for consistent title styling
extension Text {
    func customTitle() -> some View {
        self.font(.system(.headline, design: .rounded))
            .foregroundColor(.themeAccent)
    }
    
    func customSectionHeader() -> some View {
        self.font(.system(.subheadline, design: .rounded))
            .foregroundColor(.themeAccent)
            .textCase(nil)
    }
}

// Add this view modifier after the other view modifiers
struct PlaceholderTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let height: CGFloat
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: $text)
                .frame(height: height)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.8))
        )
    }
}

// Add this extension at the end of the file, before the #Preview
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Add this view modifier
struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}



