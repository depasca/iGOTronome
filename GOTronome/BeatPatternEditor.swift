//
//  BeatPatternEditor.swift
//  GOTronome
//
//  Tap a beat to cycle its sound: accent -> normal -> mute.
//

import SwiftUI

private func levelFraction(_ level: Int) -> CGFloat {
    switch level {
    case BeatLevel.accent: return 1.0
    case BeatLevel.normal: return 0.5
    default: return 0.0
    }
}

struct BeatPatternEditorView: View {
    @Binding var ts: String
    @State private var pattern: [Int] = []

    private let accentColor = Color(hex: 0xFFFD6500)

    var body: some View {
        VStack(spacing: 8) {
            Text("Accents")
                .font(.headline)
                .foregroundColor(.white)
            Text("Tap a beat to cycle its sound")
                .font(.caption)
                .foregroundColor(.gray)
            HStack(spacing: 8) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { index, level in
                    BeatCell(beatNumber: index + 1, level: level, accentColor: accentColor)
                        .onTapGesture { cycle(index) }
                }
            }
            HStack(spacing: 16) {
                LegendItem(level: BeatLevel.accent, label: "Accent", accentColor: accentColor)
                LegendItem(level: BeatLevel.normal, label: "Normal", accentColor: accentColor)
                LegendItem(level: BeatLevel.mute, label: "Mute", accentColor: accentColor)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .onAppear { pattern = AccentPattern.load(for: ts) }
        .onChange(of: ts) { newValue in pattern = AccentPattern.load(for: newValue) }
    }

    private func cycle(_ index: Int) {
        pattern = AccentPattern.cycled(pattern, at: index)
        AccentPattern.save(pattern, for: ts)
    }
}

private struct BeatCell: View {
    let beatNumber: Int
    let level: Int
    let accentColor: Color

    private static let cellHeight: CGFloat = 64

    var body: some View {
        // Fill height conveys loudness: full = accent, half = normal, empty = mute.
        ZStack {
            VStack {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(accentColor)
                    .frame(height: Self.cellHeight * levelFraction(level))
            }
            Text("\(beatNumber)")
                .font(.title2)
                .fontWeight(level == BeatLevel.accent ? .bold : .regular)
                .foregroundColor(.white)
        }
        .frame(height: Self.cellHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(accentColor, lineWidth: 2)
        )
        .contentShape(Rectangle())
    }
}

private struct LegendItem: View {
    let level: Int
    let label: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 18, height: 18 * levelFraction(level))
            }
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(accentColor, lineWidth: 1))
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    BeatPatternEditorView(ts: .constant("4/4"))
        .background(Color.black)
}
