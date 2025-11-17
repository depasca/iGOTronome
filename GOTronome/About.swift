import SwiftUI

struct InfoScreen: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 24) {
                // Header with icon, title, and close button
                HStack {
                    Image("GOTronomeIcon")
                        .resizable()
                        .frame(width: 40, height: 40)
                    
                    Spacer()
                    VStack(spacing: 4) {
                        Text("GOTronome")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                        
                        Text("Version 2.0.1")
                            .font(.body).foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.accentColor)
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal)
                
                // About Section
                InfoSectionCard(
                    title: "About GOTronome",
                    icon: "info.circle.fill",
                ) {
                    Text("GOTronome was initially created to help the GOT band rehearse. The GOT band was formed in 2023 by three 9-year-old friends and has performed at school events in front of big and enthusiastic crowds ever since. When learning a new tune it is useful for the band to practice with a metronome, though most metronomes are not designed for a band setting. GOTronome is meant to be simple and effective: big bright visuals let all band members see the beats even if they can't hear them - the band rocks much louder than the metronome :-) We believe that this app can be useful to other musicians, who are looking for a lightweight simple and effective metronome. Therefore we published the app and hope you will enjoy it as much as we do.")
                        .font(.body).foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                }
                
                // Our Promise Section
                InfoSectionCard(
                    title: "Our Promise",
                    icon: "heart"
                ) {
                    Text("This app will always be free, without ads, and without in-app purchases of any kind. We made it for fun and to help fellow musicians!")
                        .font(.body).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                // Open Source Section
                InfoSectionCard(
                    title: "Open Source",
                    icon: "star.fill"
                ) {
                    VStack(spacing: 8) {
                        Text("Love coding? GOTronome is open source! Check out the source code, contribute, suggest features or just see how it's made:")
                            .font(.body).foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                        
                        Link("https://github.com/depasca/iGOTronome", destination: URL(string: "https://github.com/depasca/iGOTronome")!)
                            .font(.body).foregroundColor(.white)
                            .foregroundColor(.accentColor)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                    }
                }
                
                Spacer(minLength: 16)
            }
            .padding(.top, 30)
            .padding(.bottom, 30)
            .padding(.horizontal, 16)
        }
        .background(Color.black.opacity(1.0))
    }
}

struct InfoSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .imageScale(.medium)
                
                Text(title)
                    .font(.title3).foregroundColor(.white)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.secondary.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// Preview
#Preview {
        InfoScreen()
}
