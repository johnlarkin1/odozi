import SwiftUI

/// Vendored subset of Phosphor Icons (fill weight) for watchOS.
/// Source: https://github.com/phosphor-icons/core (MIT license)
enum PhosphorIcon: String {
    case heartFill = "phosphor-heart-fill"
    case leafFill = "phosphor-leaf-fill"
    case lightningFill = "phosphor-lightning-fill"
    case dropFill = "phosphor-drop-fill"
    case starFill = "phosphor-star-fill"
    case sunFill = "phosphor-sun-fill"
    case wavesFill = "phosphor-waves-fill"
    case minusCircleFill = "phosphor-minus-circle-fill"
    case arrowRightFill = "phosphor-arrow-right-fill"
    case checkCircleFill = "phosphor-check-circle-fill"
    case sparkleFill = "phosphor-sparkle-fill"
    case cloudRainFill = "phosphor-cloud-rain-fill"

    var image: Image {
        Image(rawValue)
            .renderingMode(.template)
            .resizable()
    }
}
