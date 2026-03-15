import XCTest
import SwiftUI
@testable import Odyssey

/// Renders widget views to PNG screenshots in `build/widget-screenshots/`.
/// Run with: `make widget-screenshots`
@MainActor
final class WidgetSnapshotTests: XCTestCase {

    private let outputDir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("widget-screenshots")

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    // MARK: - Small Widget

    func testSmallWidgetNotLogged() throws {
        let view = SmallWidgetSnapshot(mood: nil, hasSubmitted: false, streak: 3)
        try renderAndSave(view, size: CGSize(width: 170, height: 170), name: "small_not_logged")
    }

    func testSmallWidgetMoodLogged() throws {
        let view = SmallWidgetSnapshot(mood: 7, hasSubmitted: false, streak: 5)
        try renderAndSave(view, size: CGSize(width: 170, height: 170), name: "small_mood_logged")
    }

    func testSmallWidgetFullySubmitted() throws {
        let view = SmallWidgetSnapshot(mood: 9, hasSubmitted: true, streak: 12)
        try renderAndSave(view, size: CGSize(width: 170, height: 170), name: "small_fully_submitted")
    }

    // MARK: - Medium Widget

    func testMediumWidgetNotLogged() throws {
        let view = MediumWidgetSnapshot(mood: nil, hasSubmitted: false, streak: 7)
        try renderAndSave(view, size: CGSize(width: 364, height: 170), name: "medium_not_logged")
    }

    func testMediumWidgetMoodLogged() throws {
        let view = MediumWidgetSnapshot(mood: 8, hasSubmitted: false, streak: 5)
        try renderAndSave(view, size: CGSize(width: 364, height: 170), name: "medium_mood_logged")
    }

    func testMediumWidgetFullySubmitted() throws {
        let view = MediumWidgetSnapshot(mood: 9, hasSubmitted: true, streak: 30)
        try renderAndSave(view, size: CGSize(width: 364, height: 170), name: "medium_fully_submitted")
    }

    // MARK: - Rendering

    private func renderAndSave<V: View>(_ view: V, size: CGSize, name: String) throws {
        let hosted = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: hosted)
        renderer.scale = 3.0

        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            XCTFail("Failed to render \(name)")
            return
        }

        let path = outputDir.appendingPathComponent("\(name).png")
        try data.write(to: path)

        // Also write to build dir if available
        let buildDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("build/widget-screenshots")
        try? FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        let buildPath = buildDir.appendingPathComponent("\(name).png")
        try? data.write(to: buildPath)

        print("Screenshot saved: \(path.path)")
    }
}

// MARK: - Snapshot Views
// Self-contained replicas of widget layouts using the same design tokens.
// These avoid WidgetKit/AppIntents cross-target compilation issues.

private struct SmallWidgetSnapshot: View {
    let mood: Int?
    let hasSubmitted: Bool
    let streak: Int

    private let moodOptions: [(value: Int, label: String)] = [
        (2, "Low"), (4, "Meh"), (5, "OK"), (7, "Good"), (9, "Great")
    ]

    var body: some View {
        Group {
            if let mood = mood {
                completedState(mood: mood)
            } else {
                promptState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.deepSpaceBlue)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var promptState: some View {
        VStack(spacing: 8) {
            Text("Odyssey")
                .font(.caption2.bold())
                .foregroundStyle(Color.accentAmber)

            Text("How are you?")
                .font(.caption.bold())
                .foregroundStyle(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(moodOptions, id: \.value) { option in
                    Circle()
                        .fill(Color.moodGradient(for: option.value))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("\(option.value)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        )
                }
            }

            if streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentAmber)
                    Text("\(streak)")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentAmber)
                }
            }
        }
        .padding(12)
    }

    private func completedState(mood: Int) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.moodGradient(for: mood))
                .frame(width: 52, height: 52)
                .overlay(
                    Text("\(mood)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )

            Text("Mood: \(mood)/10")
                .font(.caption.bold())
                .foregroundStyle(.white)

            if hasSubmitted {
                Label("Logged", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.successGreen)
            } else {
                Text("Tap to journal")
                    .font(.caption2)
                    .foregroundStyle(Color.accentAmber)
            }

            if streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentAmber)
                    Text("\(streak) day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }
}

private struct MediumWidgetSnapshot: View {
    let mood: Int?
    let hasSubmitted: Bool
    let streak: Int

    var body: some View {
        Group {
            if let mood = mood {
                completedState(mood: mood)
            } else {
                promptState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.deepSpaceBlue)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var promptState: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Odyssey")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentAmber)
                    Text("How are you feeling?")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                if streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.accentAmber)
                        Text("\(streak)")
                            .bold()
                            .foregroundStyle(Color.accentAmber)
                    }
                    .font(.caption)
                }
            }

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { value in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.moodGradient(for: value))
                            .frame(height: 32)
                        Text("\(value)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
    }

    private func completedState(mood: Int) -> some View {
        let moodColor = Color.moodGradient(for: mood)

        return HStack(spacing: 16) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [moodColor, moodColor.opacity(0.15)],
                                center: .center,
                                startRadius: 5,
                                endRadius: 45
                            )
                        )
                        .frame(width: 64, height: 64)

                    Text("\(mood)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("\(mood)/10")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Odyssey")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentAmber)
                    Spacer()
                }

                if hasSubmitted {
                    Label("Journal complete", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.successGreen)
                } else {
                    Label("Tap to finish journaling", systemImage: "pencil.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentAmber)
                }

                if streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.accentAmber)
                        Text("\(streak) day streak")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                HStack(spacing: 2) {
                    ForEach(1...10, id: \.self) { value in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(value == mood ? Color.moodGradient(for: value) : Color.white.opacity(0.1))
                            .frame(height: 6)
                    }
                }
            }
        }
        .padding(16)
    }
}
