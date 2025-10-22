//
//  MetronomeView.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 30.09.25.
//
import SwiftUI

struct MetronomeView: View {
    @ObservedObject var vm: MetronomeViewModel
    var containerWidth:CGFloat = UIScreen.main.bounds.width - 32
    var body: some View {
        let beatsViewWidth:CGFloat = vm.numBars > 0 ? containerWidth * 0.7 : containerWidth
        HStack {
            VStack(spacing: 14) {
                ForEach(0..<vm.beatsPerMeasure, id: \.self) { idx in
                    BeatRect(isActive: idx == vm.currentBeat, phase: vm.beatPhase)
                }
            }
            .frame(width: beatsViewWidth)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .border(Color.gray, width: 1)
            if(vm.mode == MetronomeMode.barLoop){
                VStack(spacing: 14) {
                    ForEach(0..<vm.numBars, id: \.self) { idx in
                        BeatRect(isActive: idx == vm.currentBar, phase: vm.beatPhase)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(Color.gray, width: 1)
                .frame(width: containerWidth * 0.3)
            }
        }
    }
}
    

struct BeatRect: View {
    var isActive: Bool
    var phase: Float

    var body: some View {
        let scale = isActive ? (1.0 + Double(1.0 - phase) * 0.3) : 1.0
        let color = isActive ? Color.orange : Color.black
        Rectangle()
            .foregroundColor(color)
            .scaleEffect(x: scale, y: scale, anchor: .center)
            .animation(.easeOut(duration: 0.05), value: isActive)
            .cornerRadius(12)
    }
}
