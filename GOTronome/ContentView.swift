//
//  ContentView.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 27.07.25.
//

import SwiftUI

struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

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
                    MenuView(showAbout: $showAbout, tapHandler: tapHandler)
                    if(orientation.isLandscape){
                        HStack(alignment: .top){
                            SettingsBasicView(mode: $mode, ts: $ts, bpm: $bpm)
                            SettingsAdvancedView(mode: $mode, silentBars: $silentBars, numBars: $numBars).padding(.leading, 30).padding(.top, 40)
                        }
                        .contentShape(Rectangle()).onTapGesture { tapHandler() }
                    }
                    else{
                        SettingsBasicView(mode: $mode, ts: $ts, bpm: $bpm)
                        SettingsAdvancedView(mode: $mode, silentBars: $silentBars, numBars: $numBars).padding(.top, 20)
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
                .onRotate { newOrientation in
                    print(newOrientation.rawValue.description)
                    orientation = newOrientation
                }
                
            }
        }
}

#Preview {
    ContentView()
}
