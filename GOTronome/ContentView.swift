//
//  ContentView.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 27.07.25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("ts") var ts = "4/4"
    @AppStorage("bpm") var bpm = 100.0
    @AppStorage("mode") var mode: MetronomeMode = .basic
    @AppStorage("silentBars") var silentBars = 1.0
    @AppStorage("numBars") var numBars = 16.0
    @State var isPlaying: Bool = false
    @StateObject var vm = MetronomeViewModel()
    
    private let beatsPerMeasure = 4
    private let fontColor:Color = .white
    
    func tapHandler() {
            isPlaying.toggle()
            if(isPlaying){
                vm.setMode(m: mode)
                vm.start(ts:ts, bpm:Int(bpm), ns:Int(silentBars), nb:Int(numBars))
            }
            else{
                vm.stop()
            }
    }
    
    @ViewBuilder
    var body: some View {
            if(isPlaying)
            {
                MetronomeView(vm: vm)
                    .onTapGesture { tapHandler() }
            }
            else{
                VStack(alignment: .center, spacing: 12){
                    Spacer()
                        .frame(height: 10)
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    HStack{
                        Text("Mode").foregroundColor(fontColor)
                        Picker("Mode", selection: $mode) {
                            ForEach(MetronomeMode.allCases) { m in
                                Text(String(describing: m)).foregroundColor(fontColor)
                            }
                        }.pickerStyle(.segmented)
                    }.padding(.top, 20)
                    HStack{
                        Text("Time Signature").foregroundColor(fontColor)
                        Picker(selection: $ts, label: Text("TS:")) {
                            Text("4/4").tag("4/4").foregroundColor(fontColor)
                            Text("3/4").tag("3/4").foregroundColor(fontColor)
                            Text("2/4").tag("2/4").foregroundColor(fontColor)
                            Text("2/2").tag("2/2").foregroundColor(fontColor)
                            Text("6/8").tag("6/8").foregroundColor(fontColor)
                        }.pickerStyle(.segmented)
                    }.padding(.top, 20)
                    HStack{
                        Text("Beats Per Minute").foregroundColor(fontColor)
                        Slider(value: $bpm, in: 20...240)
                        Text("\(Int(bpm))").foregroundColor(fontColor)
                    }.padding(.top, 20)
                    if(mode == .barLoop) {
                        HStack{
                            Text("Num bars").foregroundColor(fontColor)
                            Slider(value: $numBars, in: 2...32)
                            Text("\(Int(numBars))").foregroundColor(fontColor)
                        }.padding(.top, 20)
                    }
                    else{
                        if(mode == .silenBars) {
                            HStack{
                                Text("Num silent bars").foregroundColor(fontColor)
                                Slider(value: $silentBars, in: 1...10)
                                Text("\(Int(silentBars))").foregroundColor(fontColor)
                            }.padding(.top, 20)
                        }
                    }
                    Spacer()
                    Text("Tap anywhere to start/stop").foregroundColor(.white)
                }
                .padding()
                .contentShape(Rectangle())
                .onTapGesture { tapHandler() }
                .background(
                    Image("Background")
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .opacity(0.2)
                        .background(Color.black.opacity(1.0))
                    )

        }
    }
}

#Preview {
    ContentView()
}
