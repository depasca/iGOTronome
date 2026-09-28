//
//  BassControls.swift
//  GOTronome
//
//  Bass on/off and the root note; shown only for styles that carry a bass line.
//

import SwiftUI

struct BassControlsView: View {
    @Binding var enabled: Bool
    @Binding var root: Int

    var body: some View {
        SettingRow(label: "Bass") {
            Picker("Root", selection: $root) {
                ForEach(Array(rootNames.enumerated()), id: \.offset) { pitchClass, name in
                    Text("Root \(name)").tag(pitchClass)
                }
            }
            .pickerStyle(.menu)
            .colorScheme(.dark)
            .accentColor(.white)
            .disabled(!enabled)
            Toggle("Bass", isOn: $enabled)
                .labelsHidden()
                .tint(.accentColor)
                // The system off track is a translucent fill that vanishes on black.
                .background(Capsule().fill(Color.white.opacity(0.35)))
        }
    }
}

#Preview {
    BassControlsView(enabled: .constant(true), root: .constant(5))
        .padding()
        .background(Color.black)
}
