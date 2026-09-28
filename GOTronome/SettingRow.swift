//
//  SettingRow.swift
//  GOTronome
//
//  One settings row: label flush left, control flush right, one label font for every row.
//

import SwiftUI

struct SettingRow<Control: View>: View {
    let label: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.body)
                .foregroundColor(.white)
                .fixedSize()
            Spacer(minLength: 0)
            control()
        }
        .frame(minHeight: 44)
    }
}

/// A label with its typed value on the right and the slider on its own line beneath,
/// so every slider spans the same width whatever the label length.
struct SliderSettingRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 4) {
            SettingRow(label: label) {
                EditableValueView(value: $value, range: range)
            }
            Slider(value: $value, in: range).tint(.accentColor)
        }
    }
}
