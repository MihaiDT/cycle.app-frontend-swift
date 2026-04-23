import SwiftUI

// MARK: - Separated Icon (FontAwesome)

public struct SeparatedIcon: Shape {
    public func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 640.0

        var path = Path()

        // Left person head
        path.addEllipse(
            in: CGRect(
                x: 96 * scale,
                y: 64 * scale,
                width: 128 * scale,
                height: 128 * scale
            )
        )

        // Right person head
        path.addEllipse(
            in: CGRect(
                x: 416 * scale,
                y: 64 * scale,
                width: 128 * scale,
                height: 128 * scale
            )
        )

        // Left body (simplified)
        path.move(to: CGPoint(x: 64 * scale, y: 288 * scale))
        path.addLine(to: CGPoint(x: 64 * scale, y: 352 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 96 * scale, y: 407 * scale),
            control: CGPoint(x: 64 * scale, y: 380 * scale)
        )
        path.addLine(to: CGPoint(x: 96 * scale, y: 528 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 144 * scale, y: 576 * scale),
            control: CGPoint(x: 96 * scale, y: 555 * scale)
        )
        path.addLine(to: CGPoint(x: 176 * scale, y: 576 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 224 * scale, y: 528 * scale),
            control: CGPoint(x: 224 * scale, y: 555 * scale)
        )
        path.addLine(to: CGPoint(x: 224 * scale, y: 436 * scale))
        path.addLine(to: CGPoint(x: 213 * scale, y: 427 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 157 * scale, y: 269 * scale),
            control: CGPoint(x: 129 * scale, y: 298 * scale)
        )
        path.addLine(to: CGPoint(x: 202 * scale, y: 225 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 128 * scale, y: 224 * scale),
            control: CGPoint(x: 165 * scale, y: 224 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: 64 * scale, y: 288 * scale),
            control: CGPoint(x: 64 * scale, y: 224 * scale)
        )
        path.closeSubpath()

        // Right body (simplified)
        path.move(to: CGPoint(x: 576 * scale, y: 288 * scale))
        path.addLine(to: CGPoint(x: 576 * scale, y: 352 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 544 * scale, y: 407 * scale),
            control: CGPoint(x: 576 * scale, y: 380 * scale)
        )
        path.addLine(to: CGPoint(x: 544 * scale, y: 528 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 496 * scale, y: 576 * scale),
            control: CGPoint(x: 544 * scale, y: 555 * scale)
        )
        path.addLine(to: CGPoint(x: 464 * scale, y: 576 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 416 * scale, y: 528 * scale),
            control: CGPoint(x: 416 * scale, y: 555 * scale)
        )
        path.addLine(to: CGPoint(x: 416 * scale, y: 436 * scale))
        path.addLine(to: CGPoint(x: 427 * scale, y: 427 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 483 * scale, y: 269 * scale),
            control: CGPoint(x: 511 * scale, y: 298 * scale)
        )
        path.addLine(to: CGPoint(x: 438 * scale, y: 225 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 512 * scale, y: 224 * scale),
            control: CGPoint(x: 475 * scale, y: 224 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: 576 * scale, y: 288 * scale),
            control: CGPoint(x: 576 * scale, y: 224 * scale)
        )
        path.closeSubpath()

        // Arrows in center
        // Left arrow
        path.move(to: CGPoint(x: 273 * scale, y: 242 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 247 * scale, y: 247 * scale),
            control: CGPoint(x: 254 * scale, y: 238 * scale)
        )
        path.addLine(to: CGPoint(x: 191 * scale, y: 303 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 191 * scale, y: 337 * scale),
            control: CGPoint(x: 182 * scale, y: 320 * scale)
        )
        path.addLine(to: CGPoint(x: 247 * scale, y: 393 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 273 * scale, y: 398 * scale),
            control: CGPoint(x: 254 * scale, y: 400 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: 288 * scale, y: 376 * scale),
            control: CGPoint(x: 288 * scale, y: 395 * scale)
        )
        path.addLine(to: CGPoint(x: 288 * scale, y: 352 * scale))
        path.addLine(to: CGPoint(x: 352 * scale, y: 352 * scale))
        path.addLine(to: CGPoint(x: 352 * scale, y: 376 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 367 * scale, y: 398 * scale),
            control: CGPoint(x: 352 * scale, y: 395 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: 393 * scale, y: 393 * scale),
            control: CGPoint(x: 386 * scale, y: 402 * scale)
        )
        path.addLine(to: CGPoint(x: 449 * scale, y: 337 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 449 * scale, y: 303 * scale),
            control: CGPoint(x: 458 * scale, y: 320 * scale)
        )
        path.addLine(to: CGPoint(x: 393 * scale, y: 247 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 367 * scale, y: 242 * scale),
            control: CGPoint(x: 386 * scale, y: 240 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: 352 * scale, y: 264 * scale),
            control: CGPoint(x: 352 * scale, y: 246 * scale)
        )
        path.addLine(to: CGPoint(x: 352 * scale, y: 288 * scale))
        path.addLine(to: CGPoint(x: 288 * scale, y: 288 * scale))
        path.addLine(to: CGPoint(x: 288 * scale, y: 264 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 273 * scale, y: 242 * scale),
            control: CGPoint(x: 288 * scale, y: 246 * scale)
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    SeparatedIcon()
        .fill(Color.brown)
        .frame(width: 60, height: 60)
        .padding()
}
