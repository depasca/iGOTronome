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
        HStack {
            Text("Bass").foregroundColor(.white)
            Toggle("Bass", isOn: $enabled)
                .labelsHidden()
                .tint(.accentColor)
            Spacer()
            Picker("Root", selection: $root) {
                ForEach(Array(rootNames.enumerated()), id: \.offset) { pitchClass, name in
                    Text("Root \(name)").tag(pitchClass)
                }
            }
            .pickerStyle(.menu)
            .colorScheme(.dark)
            .accentColor(.white)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

#Preview {
    BassControlsView(enabled: .constant(true), root: .constant(5))
        .padding()
        .background(Color.black)
}
