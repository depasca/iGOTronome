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
                
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    HStack{
                        Text("Mode")
                        Picker("Mode", selection: $mode) {
                            ForEach(MetronomeMode.allCases) { m in
                                Text(String(describing: m))
                            }
                        }.pickerStyle(.segmented)
                    }
                    HStack{
                        Text("Time Signature")
                        Picker(selection: $ts, label: Text("TS:")) {
                            Text("4/4").tag("4/4")
                            Text("3/4").tag("3/4")
                            Text("2/4").tag("2/4")
                            Text("2/2").tag("2/2")
                            Text("6/8").tag("6/8")
                        }.pickerStyle(.wheel)
                    }
                    HStack{
                        Text("Beats Per Minute")
                        Slider(value: $bpm, in: 20...240)
                        Text("\(Int(bpm))")
                    }
                    if(mode == .barLoop) {
                        HStack{
                            Text("Num bars")
                            Slider(value: $numBars, in: 2...32)
                            Text("\(Int(numBars))")
                        }
                    }
                    else{
                        if(mode == .silenBars) {
                            HStack{
                                Text("Num silent bars")
                                Slider(value: $silentBars, in: 1...10)
                                Text("\(Int(silentBars))")
                            }
                        }
                    }
                    Spacer()
                    Text("Tap anywhere to start/stop")
                }
                .offset(y: 60)
                .padding()
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .background(Color.blue.opacity(0.2))
                .onTapGesture { tapHandler() }
        }
    }
}

#Preview {
    ContentView()
}
