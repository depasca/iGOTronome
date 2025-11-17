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
    @State var showAbout: Bool = false
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
                    HStack{
                        Menu {
                            Button("About") {
                                showAbout = true
                            }
                        } label: {
                            Label("", systemImage: "line.horizontal.3").tint(.accentColor)
                        }
                        Image("Banner")
                            .resizable()
                            .scaledToFit()
                            .border(Color.white, width: 2)
                            .onTapGesture { tapHandler() }
                    }
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
                    VStack{
                        Rectangle().frame(width: .infinity, height: .infinity)
                            .foregroundColor(.clear).contentShape(Rectangle())
                        Text("Tap anywhere to start/stop").foregroundColor(.white)
                    }
                    .onTapGesture { tapHandler() }
                }
                .padding()
                .contentShape(Rectangle())
                .background(
                    Image("Background")
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .opacity(0.2)
                        .background(Color.black.opacity(1.0))
                )
                .sheet(isPresented: $showAbout) {
                    InfoScreen()
                }
                
            }
        }
}

#Preview {
    ContentView()
}
