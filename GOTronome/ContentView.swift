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
    @State private var orientation = UIDeviceOrientation.unknown
    @State var isPortrait: Bool = false
    
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
                MetronomeView(vm: vm, isPortrait: $isPortrait)
                    .onTapGesture { tapHandler() }
            }
            else{
                VStack(alignment: .center, spacing: 12){
                    MenuView(showAbout: $showAbout, tapHandler: tapHandler)
                    if(self.isPortrait){
                        SettingsBasicView(mode: $mode, ts: $ts, bpm: $bpm)
                        SettingsAdvancedView(mode: $mode, silentBars: $silentBars, numBars: $numBars).padding(.top, 20)
                    }
                    else{
                        HStack(alignment: .top){
                            SettingsBasicView(mode: $mode, ts: $ts, bpm: $bpm)
                            SettingsAdvancedView(mode: $mode, silentBars: $silentBars, numBars: $numBars).padding(.leading, 30).padding(.top, 40)
                        }
                        .contentShape(Rectangle()).onTapGesture { tapHandler() }
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
                )
                .background(Color.black.opacity(1.0))
                .sheet(isPresented: $showAbout) {
                    InfoScreen()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    guard let scene = UIApplication.shared.windows.first?.windowScene else { return }
                    self.isPortrait = scene.interfaceOrientation.isPortrait
                }
                
            }
        }
}

#Preview {
    ContentView()
}
