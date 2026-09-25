//
//  StyleSelector.swift
//  GOTronome
//
//  Picks the drum style from a menu; only styles with a groove for the current
//  time signature are offered. Shows the effective style, so an unsupported
//  saved choice displays as Metronome without being overwritten.
//

import SwiftUI

struct StyleSelectorView: View {
    @Binding var style: String
    let timeSignature: String
    let styles: [Style]

    private var selection: Binding<String> {
        Binding(
            get: { resolveStyle(styles, savedId: style, timeSignature: timeSignature).id },
            set: { style = $0 }
        )
    }

    var body: some View {
        HStack {
            Text("Style").foregroundColor(.white)
            Spacer()
            Picker("Style", selection: selection) {
                ForEach(stylesFor(styles, timeSignature: timeSignature)) { option in
                    Text(option.name).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .colorScheme(.dark)
            .accentColor(.white)
        }
    }
}

#Preview {
    StyleSelectorView(style: .constant("rock"), timeSignature: "4/4", styles: loadBundledStyles())
        .padding()
        .background(Color.black)
}
