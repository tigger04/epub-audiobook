// ABOUTME: Sleep timer preset picker with cancel option.
// ABOUTME: Shows countdown when active.

import SwiftUI

struct SleepTimerView: View {
    let timerService: SleepTimerService

    @Environment(\.dismiss) private var dismiss

    private let presets: [(label: String, option: SleepTimerOption)] = [
        ("15 min", .minutes(15)),
        ("30 min", .minutes(30)),
        ("45 min", .minutes(45)),
        ("60 min", .minutes(60)),
        ("End of chapter", .endOfChapter),
    ]

    var body: some View {
        NavigationStack {
            List {
                if timerService.isActive {
                    Section("Active Timer") {
                        HStack {
                            Text(timerService.formattedRemaining)
                                .font(.title2)
                                .monospacedDigit()
                            Spacer()
                            Button("Cancel", role: .destructive) {
                                timerService.cancel()
                            }
                        }
                    }
                }

                Section("Set Timer") {
                    ForEach(presets, id: \.label) { preset in
                        Button(preset.label) {
                            timerService.start(option: preset.option)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
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
}
