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
        let fontColor: Color = .white
        VStack{
            HStack{
                Text("Mode").foregroundColor(fontColor)
                Picker("Mode", selection: $mode) {
                    ForEach(MetronomeMode.allCases) { m in
                        Text(String(describing: m))
                    }
                }.pickerStyle(.segmented).colorScheme(.dark)
            }.padding(.top, 40)
            HStack{
                Text("Time Signature").foregroundColor(fontColor)
                Picker(selection: $ts, label: Text("TS:")) {
                    Text("4/4").tag("4/4").foregroundColor(fontColor)
                    Text("3/4").tag("3/4").foregroundColor(fontColor)
                    Text("2/4").tag("2/4").foregroundColor(fontColor)
                    Text("2/2").tag("2/2").foregroundColor(fontColor)
                    Text("6/8").tag("6/8").foregroundColor(fontColor)
                }.pickerStyle(.segmented).colorScheme(.dark)
            }.padding(.top, 20)
            HStack{
                Text("Beats Per Minute").foregroundColor(fontColor)
                Slider(value: $bpm, in: 20...240).tint(.accentColor)
                Text("\(Int(bpm))").foregroundColor(fontColor)
            }.padding(.top, 20)
        }
        .background(Color.black)
    }
}


#Preview{
    SettingsBasicView(mode: .constant(.basic), ts: .constant("4/4"), bpm: .constant(120))
}
