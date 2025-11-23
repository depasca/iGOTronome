//
//  menu.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 23.11.25.
//
import SwiftUI

struct MenuView: View {
    @Binding var showAbout: Bool
    var tapHandler: () -> Void
    
    var body: some View {
        ZStack{
            RoundedRectangle(cornerRadius: 4)
                .foregroundColor(.accentColor)
                .border(.white, width: 2)
                .cornerRadius(4)
            HStack{
                Menu {
                    Button("About") {
                        showAbout = true
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
