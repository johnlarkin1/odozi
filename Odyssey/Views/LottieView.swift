//
//  LottieView.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    
    var lottieFile: String
    var loopMode: LottieLoopMode = .playOnce
    var animationView = LottieAnimationView()
    
    func makeUIView(context: UIViewRepresentableContext<LottieView>) -> UIView {
        let view = UIView()
        
        animationView.animation = LottieAnimation.named(lottieFile)
        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = loopMode
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<LottieView>) {
        animationView.play()
    }
}

#Preview {
    LottieView(lottieFile: "rotating_earth")
}
