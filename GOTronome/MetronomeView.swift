//
//  MetronomeView.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 30.09.25.
//
import SwiftUI

struct MetronomeView: View {
    @ObservedObject var vm: MetronomeViewModel
    @Binding var isPortrait: Bool
    var body: some View {
        HStack{
            if isPortrait {
                MetronomeViewVertical(vm: vm)
            } else {
                MetronomeViewHorizontal(vm: vm)
            }
        }
    }
}
    

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: opacity
        )
    }
}

struct MetronomeViewVertical: View {
    @ObservedObject var vm: MetronomeViewModel
    var containerWidth:CGFloat = UIScreen.main.bounds.width - 32
    var body: some View {
        Group {
            if vm.isCountingIn {
                CountInView(count: vm.currentBeat + 1, beatsPerMeasure: vm.beatsPerMeasure)
            } else {
                HStack (alignment: .center, spacing: 8){
                    VStack(spacing: 4) {
                        ForEach(0..<vm.beatsPerMeasure, id: \.self) { idx in
                            BeatRect(num: idx, isActive: idx == vm.currentBeat, phase: vm.beatPhase, isSilent: vm.isSilentBar)
                        }
                    }
                    if(vm.mode == MetronomeMode.barLoop){
                        VStack(spacing: 4) {
                            ForEach(0..<vm.numBars, id: \.self) { idx in
                                BarRect(num: idx, isActive: idx == vm.currentBar, phase: vm.beatPhase)
                            }
                        }
                        .frame(width: containerWidth * 0.3)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(1.0))
    }
}

struct MetronomeViewHorizontal: View {
    @ObservedObject var vm: MetronomeViewModel
    var containerHeight:CGFloat = UIScreen.main.bounds.height - 32
    var body: some View {
        Group {
            if vm.isCountingIn {
                CountInView(count: vm.currentBeat + 1, beatsPerMeasure: vm.beatsPerMeasure)
            } else {
                VStack (alignment: .center, spacing: 8){
                    HStack(spacing: 4) {
                        ForEach(0..<vm.beatsPerMeasure, id: \.self) { idx in
                            BeatRect(num: idx, isActive: idx == vm.currentBeat, phase: vm.beatPhase, isSilent: vm.isSilentBar)
                        }
                    }
                    if(vm.mode == MetronomeMode.barLoop){
                        HStack(spacing: 4) {
                            ForEach(0..<vm.numBars, id: \.self) { idx in
                                BarRect(num: idx, isActive: idx == vm.currentBar, phase: vm.beatPhase)
                            }
                        }
                        .frame(height: containerHeight * 0.3)
                    }
                }
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
    var isSilent: Bool = false

    var body: some View {
        let scale = isSilent ? 1.0 : isActive ? (1.0 + Double(1.0 - phase) * 0.3) : 1.0
        let color = isSilent ? Color.black : isActive ? (num == 0 ? Color(hex: 0xFFD73F06) : Color(hex: 0xFFFD6500)) :  Color.black
        let borderColor = num == 0 ? Color(hex: 0xFFD73F06) : Color(hex: 0xFFFD6500)
        let fontSize: CGFloat = 72
        let fontColor: Color = .white
        let cornerRadius: CGFloat = 12
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


struct CountInView: View {
    var count: Int              // 1..N
    var beatsPerMeasure: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("COUNT IN")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("\(max(count, 1))")
                .font(.system(size: 140))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: 0xFFFD6500))
            HStack(spacing: 12) {
                ForEach(0..<beatsPerMeasure, id: \.self) { i in
                    Circle()
                        .fill(i < count ? Color(hex: 0xFFFD6500) : Color(hex: 0xFF282828))
                        .frame(width: 20, height: 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct BarRect: View {
    var num: Int
    var isActive: Bool
    var phase: Float

    var body: some View {
        let scale = isActive ? (1.0 + Double(1.0 - phase) * 0.3) : 1.0
        let color = isActive ? Color(hex: 0xFFFD6500) : Color(hex: 0xFF282828)
        let fontSize: CGFloat = 12
        let fontColor: Color = isActive ? .white: .orange
        let cornerRadius: CGFloat = 8
        ZStack{
            Rectangle()
                .foregroundColor(color)
                .scaleEffect(x: scale, y: scale, anchor: .center)
                .animation(.easeOut(duration: 0.05), value: isActive)
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .foregroundColor(.clear)
                )
                .padding(2)
            Text("\(num + 1)")
                .font(.system(size: fontSize))
                .fontWeight(.bold)
                .foregroundColor(fontColor)
        }
    }
}

#Preview {
    let vm = MetronomeViewModel()
    MetronomeView(vm: vm, isPortrait: .constant(false))
}
