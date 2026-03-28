import SwiftUI

struct PhotoMapPin: View {
    let image: UIImage
    let moodColor: Color

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(moodColor, lineWidth: 2.5)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }
}
