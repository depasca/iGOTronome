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
    @AppStorage("countIn") var countIn = true
    @State var isPlaying: Bool = false
    @State var showAbout: Bool = false
    @StateObject var vm = MetronomeViewModel()
    @State var isPortrait: Bool = true
    
    private let beatsPerMeasure = 4
    private let fontColor:Color = .white
    
    func tapHandler() {
            isPlaying.toggle()
            if(isPlaying){
                vm.setMode(m: mode)
                vm.start(ts:ts, bpm:Int(bpm), ns:Int(silentBars), nb:Int(numBars), countIn: countIn)
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
                            BeatPatternEditorView(ts: $ts).padding(.top, 20)
                            Rectangle()
                                .foregroundColor(.clear)
                                .contentShape(Rectangle())
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onTapGesture { tapHandler() }
                        }
                        else{
                            HStack(alignment: .top){
                                SettingsBasicView(mode: $mode, ts: $ts, bpm: $bpm)
                                VStack{
                                    SettingsAdvancedView(mode: $mode, silentBars: $silentBars, numBars: $numBars).padding(.leading, 30).padding(.top, 40)
                                    Rectangle()
                                        .foregroundColor(.clear)
                                        .contentShape(Rectangle())
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .onTapGesture { tapHandler() }
                                }
                            }
                            
                        }
                    Text("Tap anywhere to start/stop").foregroundColor(.white)
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
                        // Find the active foreground scene and determine orientation
                        let scenes = UIApplication.shared.connectedScenes
                        if let windowScene = scenes
                            .compactMap({ $0 as? UIWindowScene })
                            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
                            self.isPortrait = windowScene.interfaceOrientation.isPortrait
                        }
                    }
                }
        }
}

#Preview {
    ContentView()
}
