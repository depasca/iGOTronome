//
//  menu.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 23.11.25.
//
import SwiftUI

/// Our App Store listing; opening it is what "check for updates" does, since the store shows
/// Update or Open depending on what the user already has.
private let appStoreListing = URL(string: "https://apps.apple.com/app/id6755876341")

struct MenuView: View {
    @Binding var showAbout: Bool
    var tapHandler: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack{
            RoundedRectangle(cornerRadius: 4)
                .foregroundColor(Color(hex: 0xFFFD6500))
                .border(.white, width: 2)
                .cornerRadius(4)
            HStack{
                Menu {
                    Button("About") {
                        showAbout = true
                    }
                    Button("Check for updates") {
                        if let appStoreListing { openURL(appStoreListing) }
                    }
                }
                label: {
                    Label("", systemImage: "line.horizontal.3").tint(.white).padding(.leading, 8)
                }
                Spacer()
                Image("Banner")
                    .resizable()
                    .scaledToFit()
                    .onTapGesture { tapHandler() }
                Spacer()
            }
        }.frame(minHeight: 50, maxHeight: 100)
            .background(.black)

    }
}

#Preview {
    MenuView(
        showAbout: .constant(false),
        tapHandler: { print("Tapped!")}
    )
}
