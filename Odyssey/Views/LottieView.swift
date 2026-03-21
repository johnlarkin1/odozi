//
//  LottieView.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import Lottie
import SwiftUI

#if os(macOS)
    struct LottieView: NSViewRepresentable {
        var lottieFile: String
        var loopMode: LottieLoopMode = .playOnce
        var animationView = LottieAnimationView()

        func makeNSView(context _: Context) -> NSView {
            let view = NSView()

            animationView.animation = LottieAnimation.named(lottieFile)
            animationView.contentMode = .scaleAspectFill
            animationView.loopMode = loopMode

            animationView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(animationView)

            NSLayoutConstraint.activate([
                animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
                animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            ])

            return view
        }

        func updateNSView(_: NSView, context _: Context) {
            animationView.play()
        }
    }
#else
    struct LottieView: UIViewRepresentable {
        var lottieFile: String
        var loopMode: LottieLoopMode = .playOnce
        var animationView = LottieAnimationView()

        func makeUIView(context _: UIViewRepresentableContext<LottieView>) -> UIView {
            let view = UIView()

            animationView.animation = LottieAnimation.named(lottieFile)
            animationView.contentMode = .scaleAspectFill
            animationView.loopMode = loopMode

            animationView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(animationView)

            NSLayoutConstraint.activate([
                animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
                animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            ])

            return view
        }

        func updateUIView(_: UIView, context _: UIViewRepresentableContext<LottieView>) {
            animationView.play()
        }
    }
#endif

#Preview {
    LottieView(lottieFile: "rotating_earth")
}
