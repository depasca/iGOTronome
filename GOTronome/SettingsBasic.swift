//
//  SettingsBasic.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 22.11.25.
//

import SwiftUI

struct SettingsBasicView: View {
    @Binding var mode: MetronomeMode
    @Binding var ts: String
    @Binding var bpm: Double
    var body: some View {
        VStack(spacing: 12) {
            SettingRow(label: "Mode") {
                Picker("Mode", selection: $mode) {
                    ForEach(MetronomeMode.allCases) { m in
                        Text(String(describing: m))
                    }
                }.pickerStyle(.segmented).colorScheme(.dark)
            }
            SettingRow(label: "Time Signature") {
                Picker(selection: $ts, label: Text("Time Signature")) {
                    ForEach(["4/4", "3/4", "2/4", "2/2", "6/8"], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }.pickerStyle(.segmented).colorScheme(.dark)
            }
            SliderSettingRow(label: "Beats Per Minute", value: $bpm, range: 20...240)
        }
        .padding(.top, 20)
        .background(Color.black)
    }
}


#Preview{
    SettingsBasicView(mode: .constant(.basic), ts: .constant("4/4"), bpm: .constant(120))
}
