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
    @AppStorage("mode") var mode: String = "Basic"
    @State var isPlaying: Bool = false
    @State var silentBars = 0.0
    @State var numBars = 16.0
    @StateObject var vm = MetronomeViewModel()
    private let beatsPerMeasure = 4
    
    func tapHandler() {
            debugPrint("Tapped")
            isPlaying.toggle()
            if(isPlaying){
                vm.setShowBars(sb: mode == "Bar loop")
                if(mode == "Bar loop"){
                    vm.setNumBars(nb: Int(numBars))
                }
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
                VStack {
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    HStack{
                        Text("Time Signature")
                        Picker(selection: $ts, label: Text("TS:")) {
                            Text("4/4").tag("4/4")
                            Text("3/4").tag("3/4")
                            Text("2/4").tag("2/4")
                            Text("2/2").tag("2/2")
                            Text("6/8").tag("6/8")
                        }.pickerStyle(MenuPickerStyle())
                    }
                    HStack{
                        Text("Beats Per Minute")
                        Slider(value: $bpm, in: 20...240)
                        Text("\(Int(bpm))")
                    }
                    HStack{
                        Text("Mode")
                        Picker(selection: $mode, label: Text("Mode:")) {
                            Text("Basic").tag("Basic")
                            Text("Silent bars").tag("Silent bars")
                            Text("Bar loop").tag("Bar loop")
                        }.pickerStyle(MenuPickerStyle())
                    }
                    if(mode == "Bar loop") {
                        HStack{
                            Text("num bars")
                            Slider(value: $numBars, in: 1...16)
                            Text("\(Int(numBars))")
                        }.frame( maxWidth: .infinity, maxHeight: .infinity)
                    }
                    else{
                        if(mode == "Silent bars") {
                            HStack{
                                Text("num bars")
                                Slider(value: $silentBars, in: 1...4)
                                Text("\(Int(silentBars))")
                            }.frame( maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                
                    Text("Tap anywhere to start/stop")
                }
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
