//
//  SettingsAdvanced.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 22.11.25.
//



import SwiftUI

struct SettingsAdvancedView: View {
    @Binding var mode: MetronomeMode
    @Binding var silentBars: Double
    @Binding var numBars: Double
    var body: some View {
        let fontColor: Color = .white
        VStack {
            if(mode == .barLoop) {
                HStack{
                    Text("Num bars").foregroundColor(fontColor)
                    Slider(value: $numBars, in: 2...32).tint(.accentColor)
                    Text("\(Int(numBars))").foregroundColor(fontColor)
                }.padding(.top, 20)
            }
            else{
                if(mode == .silenBars) {
                    HStack{
                        Text("Num silent bars").foregroundColor(fontColor)
                        Slider(value: $silentBars, in: 1...10).tint(.accentColor)
                        Text("\(Int(silentBars))").foregroundColor(fontColor)
                    }.padding(.top, 20)
                }
            }
        }
        .background(Color.black)
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
