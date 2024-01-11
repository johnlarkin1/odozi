//
//  HomeView.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import SwiftUI

struct HomeView: View {
    @Binding var showingHomeView: Bool
    @State private var isSpinning = false
    @State private var showEntryButton = false
    @State private var buttonOpacity = 0.0

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                
                Text("Welcome to Odyssey")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                    .padding()

                LottieView(lottieFile: "rotating_earth", loopMode: .loop)
                    .frame(width: 300, height: 300) // Adjust the size as needed
                
                Spacer()
                
                if showEntryButton {
                    Button("Go to Today's Entry") {
                        self.showingHomeView = false
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green.opacity(0.75)) // Slightly transparent background
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 1)
                    )
                    .shadow(radius: 5)
                    .padding(.bottom, 30) // Add some padding at the bottom
                    .opacity(buttonOpacity)
                }

            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // 2 seconds delay
                withAnimation(.easeInOut(duration: 2.0)) {
                    self.showEntryButton = true
                    withAnimation(.easeInOut(duration: 3.0)) {
                        self.buttonOpacity = 1.0
                    }
                }
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(showingHomeView: .constant(true))
    }
}
