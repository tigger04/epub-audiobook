// ABOUTME: Settings view for voice selection and default playback speed.
// ABOUTME: Persists preferences via AppStorage and lists available system voices.

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @AppStorage("defaultSpeed") private var defaultSpeed: Double = 0.5
    @AppStorage("selectedVoiceIdentifier") private var selectedVoiceIdentifier: String = ""
    @AppStorage("showTextHighlighting") private var showTextHighlighting = true

    @Environment(\.dismiss) private var dismiss

    private var groupedVoices: [(language: String, voices: [AVSpeechSynthesisVoice])] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let grouped = Dictionary(grouping: allVoices) { voice in
            Locale.current.localizedString(forLanguageCode: voice.language) ?? voice.language
        }
        return grouped.sorted { $0.key < $1.key }
            .map { (language: $0.key, voices: $0.value.sorted { $0.name < $1.name }) }
    }

    private let speedOptions: [(label: String, value: Double)] = [
        ("0.5x", 0.25),
        ("0.75x", 0.375),
        ("1x", 0.5),
        ("1.25x", 0.625),
        ("1.5x", 0.75),
        ("2x", 1.0),
    ]

    var body: some View {
        NavigationStack {
            Form {
                speedSection
                displaySection
                voiceSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var speedSection: some View {
        Section("Default Speed") {
            Picker("Speed", selection: $defaultSpeed) {
                ForEach(speedOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var displaySection: some View {
        Section("Display") {
            Toggle("Highlight Current Word", isOn: $showTextHighlighting)
        }
    }

    private var voiceSection: some View {
        Section("Voice") {
            ForEach(groupedVoices, id: \.language) { group in
                DisclosureGroup(group.language) {
                    ForEach(group.voices, id: \.identifier) { voice in
                        voiceRow(voice)
                    }
                }
            }
        }
    }

    private func voiceRow(_ voice: AVSpeechSynthesisVoice) -> some View {
        Button {
            selectedVoiceIdentifier = voice.identifier
            previewVoice(voice)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(voice.name)
                        .font(.body)
                    Text(voice.language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if voice.identifier == selectedVoiceIdentifier {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Preview

    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        let utterance = AVSpeechUtterance(string: "This is a preview of the selected voice.")
        utterance.voice = voice
        utterance.rate = Float(defaultSpeed) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) + AVSpeechUtteranceMinimumSpeechRate
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}
