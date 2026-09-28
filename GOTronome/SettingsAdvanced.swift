//
//  SettingsAdvanced.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 22.11.25.
//



import SwiftUI

// With one audible bar, longer gaps leave too little click to re-lock the tempo.
let maxSilentBars = 8.0

struct SettingsAdvancedView: View {
    @Binding var mode: MetronomeMode
    @Binding var silentBars: Double
    @Binding var numBars: Double
    var body: some View {
        VStack {
            if mode == .barLoop {
                SliderSettingRow(label: "Loop bars", value: $numBars, range: 2...32)
            } else if mode == .silenBars {
                SliderSettingRow(label: "Silent bars", value: $silentBars, range: 1...maxSilentBars)
            }
        }
        .background(Color.black)
        // Earlier versions allowed up to 10.
        .onAppear { silentBars = min(silentBars, maxSilentBars) }
    }
}

#Preview {
    SettingsAdvancedView(
        mode: .constant(.silenBars),
        silentBars: .constant(5.0),
        numBars: .constant(8.0)
    )
    SettingsAdvancedView(
        mode: .constant(.barLoop),
        silentBars: .constant(5.0),
        numBars: .constant(8.0)
    )
}
