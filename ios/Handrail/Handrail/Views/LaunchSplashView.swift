import SwiftUI

struct LaunchSplashView: View {
    private let animationDuration = 2.0
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let progress = min(elapsed / animationDuration, 1)

            GeometryReader { geometry in
                let markSize = splashSize(for: geometry.size)

                ZStack {
                    Color.black.ignoresSafeArea()

                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.26),
                            Color.purple.opacity(0.06),
                            Color.black.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: markSize * 1.25
                    )
                    .frame(
                        width: markSize * 2.1,
                        height: markSize * 2.1
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                    CodexInspiredLaunchMark(progress: progress)
                        .frame(
                            width: markSize,
                            height: markSize
                        )
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            startDate = Date()
        }
    }

    private func splashSize(for size: CGSize) -> CGFloat {
        min(size.width * 0.76, size.height * 0.42)
    }
}

private struct CodexInspiredLaunchMark: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.purple.opacity(outerRingOpacity), lineWidth: 2)
                .scaleEffect(0.92 + progress * 0.08)

            LaunchPolygon(points: greenPoints)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(progress * 240))
                .scaleEffect(0.72 + progress * 0.12)
                .shadow(color: .green.opacity(0.55), radius: 12)

            LaunchPolygon(points: purplePoints)
                .stroke(Color.purple, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(22 + progress * 330))
                .scaleEffect(0.7 + progress * 0.1)
                .shadow(color: .purple.opacity(0.7), radius: 10)

            LaunchPolygon(points: bluePoints)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-18 - progress * 290))
                .scaleEffect(0.73 + progress * 0.09)
                .shadow(color: .blue.opacity(0.45), radius: 8)

            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .shadow(color: .white.opacity(0.95), radius: 16)
                .shadow(color: .purple.opacity(0.9), radius: 28)
                .scaleEffect(0.8 + centerPulse * 0.2)
        }
        .opacity(0.35 + progress * 0.65)
        .scaleEffect(0.86 + progress * 0.14)
    }

    private var centerPulse: Double {
        sin(progress * .pi)
    }

    private var outerRingOpacity: Double {
        0.46 + centerPulse * 0.38
    }

    private var greenPoints: [CGPoint] {
        [
            CGPoint(x: 0.38, y: 0.14),
            CGPoint(x: 0.68, y: 0.22),
            CGPoint(x: 0.78, y: 0.52),
            CGPoint(x: 0.55, y: 0.76),
            CGPoint(x: 0.26, y: 0.64),
            CGPoint(x: 0.2, y: 0.36)
        ]
    }

    private var purplePoints: [CGPoint] {
        [
            CGPoint(x: 0.49, y: 0.16),
            CGPoint(x: 0.76, y: 0.42),
            CGPoint(x: 0.61, y: 0.72),
            CGPoint(x: 0.28, y: 0.69),
            CGPoint(x: 0.18, y: 0.4)
        ]
    }

    private var bluePoints: [CGPoint] {
        [
            CGPoint(x: 0.24, y: 0.55),
            CGPoint(x: 0.43, y: 0.22),
            CGPoint(x: 0.75, y: 0.38),
            CGPoint(x: 0.7, y: 0.71),
            CGPoint(x: 0.38, y: 0.78)
        ]
    }
}

private struct LaunchPolygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let firstPoint = points.first else {
            return path
        }

        path.move(to: point(firstPoint, in: rect))
        for point in points.dropFirst() {
            path.addLine(to: self.point(point, in: rect))
        }
        path.closeSubpath()
        return path
    }

    private func point(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }
}

#Preview {
    LaunchSplashView()
}
