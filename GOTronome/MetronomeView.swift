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
        let beatsViewWidth:CGFloat = vm.mode == MetronomeMode.barLoop && vm.numBars > 0 ? containerWidth * 0.7 : containerWidth
        HStack (alignment: .center, spacing: 8){
            VStack(spacing: 4) {
                ForEach(0..<vm.beatsPerMeasure, id: \.self) { idx in
                    BeatRect(num: idx, isActive: idx == vm.currentBeat, phase: vm.beatPhase)
                }
            }
//            .frame(width: beatsViewWidth)
            if(vm.mode == MetronomeMode.barLoop){
                VStack(spacing: 4) {
                    ForEach(0..<vm.numBars, id: \.self) { idx in
                        BeatRect(num: idx, isActive: idx == vm.currentBar, phase: vm.beatPhase, isBeat: false)
                    }
                }
                .frame(width: containerWidth * 0.3)
            }
        }
        .padding(8)
        .background(Color.black.opacity(1.0))
    }
}
    

struct BeatRect: View {
    var num: Int
    var isActive: Bool
    var phase: Float
    var isBeat: Bool = true

    var body: some View {
        let scale = isActive ? (1.0 + Double(1.0 - phase) * 0.3) : 1.0
        let color = isActive ? Color.orange : Color.black
        let borderColor = num == 0 ? Color.red : Color.orange
        let fontSize: CGFloat = isBeat ? 96 : 12
        let fontColor: Color = isBeat ? .white : isActive ? .white: .orange
        let cornerRadius: CGFloat = isBeat ? 12 : 6
        ZStack{
            Rectangle()
                .foregroundColor(color)
                .scaleEffect(x: scale, y: scale, anchor: .center)
                .animation(.easeOut(duration: 0.05), value: isActive)
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, style: StrokeStyle(lineWidth: 3))
                        .foregroundColor(.clear)
                )
                .padding(4)
            Text("\(num + 1)")
                .font(.system(size: fontSize))
                .fontWeight(.bold)
                .foregroundColor(fontColor)
        }
    }
}
