// ABOUTME: Segmented speed control for TTS playback rate.
// ABOUTME: Offers preset speeds from 0.5x to 2.0x.

import SwiftUI

struct SpeedControlView: View {
    let coordinator: PlaybackCoordinator

    private let speeds: [(label: String, value: Float)] = [
        ("0.5x", 0.25),
        ("0.75x", 0.375),
        ("1x", 0.5),
        ("1.25x", 0.625),
        ("1.5x", 0.75),
        ("2x", 1.0),
    ]

    var body: some View {
        VStack(spacing: 4) {
            Text("Speed")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(speeds, id: \.value) { speed in
                    Button {
                        coordinator.setRate(speed.value)
                    } label: {
                        Text(speed.label)
                            .font(.caption)
                            .fontWeight(isSelected(speed.value) ? .bold : .regular)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                isSelected(speed.value) ? Color.accentColor.opacity(0.2) : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func isSelected(_ value: Float) -> Bool {
        abs(coordinator.rate - value) < 0.01
    }
}
