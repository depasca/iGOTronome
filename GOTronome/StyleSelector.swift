//
//  StyleSelector.swift
//  GOTronome
//
//  Picks the drum style; only styles with a groove for the current time
//  signature are offered. Shows the effective style, so an unsupported saved
//  choice displays as Metronome without being overwritten. Buttons wrap into
//  rows of three so every style name fits, unlike a segmented control.
//

import SwiftUI

private let stylesPerRow = 3

private func rows<T>(_ items: [T], of size: Int) -> [[T]] {
    stride(from: 0, to: items.count, by: size).map { Array(items[$0..<min($0 + size, items.count)]) }
}

struct StyleSelectorView: View {
    @Binding var style: String
    let timeSignature: String
    let styles: [Style]

    private var effectiveId: String {
        resolveStyle(styles, savedId: style, timeSignature: timeSignature).id
    }

    var body: some View {
        HStack(alignment: .top) {
            Text("Style").foregroundColor(.white).padding(.top, 6)
            VStack(spacing: 8) {
                ForEach(Array(rows(stylesFor(styles, timeSignature: timeSignature), of: stylesPerRow).enumerated()),
                        id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        ForEach(row) { option in
                            StyleButton(name: option.name, selected: option.id == effectiveId) { style = option.id }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct StyleButton: View {
    let name: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color(white: 0.45) : Color(white: 0.16)))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StyleSelectorView(style: .constant("rock"), timeSignature: "4/4", styles: loadBundledStyles())
        .padding()
        .background(Color.black)
}
