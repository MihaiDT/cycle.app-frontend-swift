import SwiftUI

// MARK: - Cosmic Particle Emitter

struct CosmicParticleEmitter: UIViewRepresentable {
    let displayDay: Int
    let cycleLength: Int

    func makeUIView(context: Context) -> CosmicParticleView {
        let v = CosmicParticleView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.displayDay = displayDay
        v.cycleLen = cycleLength
        return v
    }

    func updateUIView(_ v: CosmicParticleView, context: Context) {
        guard v.displayDay != displayDay || v.cycleLen != cycleLength else { return }
        v.displayDay = displayDay
        v.cycleLen = cycleLength
        if Thread.isMainThread { v.rebuildEmitters() } else { DispatchQueue.main.async { v.rebuildEmitters() } }
    }
}

final class CosmicParticleView: UIView {
    private var fieldLayer: CAEmitterLayer?
    private var vortexLayer: CAEmitterLayer?
    var displayDay: Int = 1
    var cycleLen: Int = 28

    override func layoutSubviews() {
        super.layoutSubviews()
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [self] in rebuildEmitters() }
            return
        }
        rebuildEmitters()
    }

    func rebuildEmitters() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 20
        guard radius > 10 else { return }

        let startA = -Double.pi / 2
        let fillFrac = Double(displayDay) / Double(max(cycleLen, 1))
        let fillA = fillFrac * 2 * .pi + startA
        let unfilled = startA + 2 * .pi - fillA

        guard unfilled > 0.02 else {
            fieldLayer?.removeFromSuperlayer()
            vortexLayer?.removeFromSuperlayer()
            fieldLayer = nil
            vortexLayer = nil
            return
        }

        if fieldLayer == nil {
            let fl = CAEmitterLayer()
            fl.renderMode = .additive
            let vl = CAEmitterLayer()
            vl.renderMode = .additive
            layer.addSublayer(fl)
            layer.addSublayer(vl)
            fieldLayer = fl
            vortexLayer = vl
        }
        guard let fieldLayer, let vortexLayer else { return }

        let spanFactor = Float(max(0.15, unfilled / (2 * .pi)))

        let roseTaupe = UIColor(red: 0xC8 / 255, green: 0xAD / 255, blue: 0xA7 / 255, alpha: 1)
        let dustyRose = UIColor(red: 0xD6 / 255, green: 0xA5 / 255, blue: 0x9A / 255, alpha: 1)
        let softBlush = UIColor(red: 0xEB / 255, green: 0xCF / 255, blue: 0xC3 / 255, alpha: 1)
        let sandstone = UIColor(red: 0xDE / 255, green: 0xCB / 255, blue: 0xC1 / 255, alpha: 1)

        // Field emitter
        fieldLayer.emitterPosition = center
        fieldLayer.emitterSize = CGSize(width: radius * 2, height: radius * 2)
        fieldLayer.emitterShape = .circle
        fieldLayer.emitterMode = .outline
        fieldLayer.birthRate = spanFactor

        let dust = makeCell(
            birth: 40,
            life: 5.5,
            vel: 4,
            scale: 0.018,
            color: roseTaupe.withAlphaComponent(0.3),
            image: Self.circleImg
        )
        let glow = makeCell(
            birth: 12,
            life: 6.5,
            vel: 3,
            scale: 0.035,
            color: softBlush.withAlphaComponent(0.12),
            image: Self.glowImg
        )
        let sparkle = makeCell(
            birth: 14,
            life: 2.5,
            vel: 2,
            scale: 0.006,
            color: dustyRose.withAlphaComponent(0.4),
            image: Self.circleImg
        )
        let shimmer = makeCell(
            birth: 5,
            life: 4.0,
            vel: 1.5,
            scale: 0.025,
            color: sandstone.withAlphaComponent(0.18),
            image: Self.glowImg
        )
        fieldLayer.emitterCells = [dust, glow, sparkle, shimmer]

        // Mask
        let maskSize = bounds.size
        guard maskSize.width > 0 else { return }
        let fadeA = min(Double.pi * 0.12, unfilled * 0.3)
        let endA = startA + 2 * .pi
        let renderer = UIGraphicsImageRenderer(size: maskSize)
        let maskImg = renderer.image { imgCtx in
            let gc = imgCtx.cgContext
            let lw: CGFloat = 50
            // Fade in
            for i in 0..<12 {
                let t = Double(i) / 12
                let tN = Double(i + 1) / 12
                let seg = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: fillA + t * fadeA,
                    endAngle: fillA + tN * fadeA,
                    clockwise: true
                )
                gc.setStrokeColor(UIColor(white: 1, alpha: CGFloat(t * t)).cgColor)
                gc.setLineWidth(lw)
                gc.setLineCap(.butt)
                gc.addPath(seg.cgPath)
                gc.strokePath()
            }
            // Full zone
            let fS = fillA + fadeA
            let fE = endA - fadeA
            if fE > fS {
                let full = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: fS,
                    endAngle: fE,
                    clockwise: true
                )
                gc.setStrokeColor(UIColor.white.cgColor)
                gc.setLineWidth(lw)
                gc.setLineCap(.butt)
                gc.addPath(full.cgPath)
                gc.strokePath()
            }
            // Fade out
            for i in 0..<12 {
                let t = Double(i) / 12
                let tN = Double(i + 1) / 12
                let seg = UIBezierPath(
                    arcCenter: center,
                    radius: radius,
                    startAngle: endA - fadeA + t * fadeA,
                    endAngle: endA - fadeA + tN * fadeA,
                    clockwise: true
                )
                gc.setStrokeColor(UIColor(white: 1, alpha: CGFloat((1 - tN) * (1 - tN))).cgColor)
                gc.setLineWidth(lw)
                gc.setLineCap(.butt)
                gc.addPath(seg.cgPath)
                gc.strokePath()
            }
        }
        let maskLayer = CALayer()
        maskLayer.frame = bounds
        maskLayer.contents = maskImg.cgImage
        fieldLayer.mask = maskLayer

        // Vortex emitter
        let vAngle = fillA + 0.08
        let vx = center.x + cos(vAngle) * radius
        let vy = center.y + sin(vAngle) * radius
        vortexLayer.emitterPosition = CGPoint(x: vx, y: vy)
        vortexLayer.emitterSize = CGSize(width: 44, height: 44)
        vortexLayer.emitterShape = .circle
        vortexLayer.emitterMode = .surface
        vortexLayer.birthRate = spanFactor

        let inward = atan2(center.y - vy, center.x - vx)
        let toward = fillA - .pi / 2
        let absorbA = CGFloat((inward + toward) / 2)

        let aDust = makeCell(
            birth: 22,
            life: 1.0,
            vel: 12,
            scale: 0.015,
            color: roseTaupe.withAlphaComponent(0.35),
            image: Self.circleImg,
            emissionLong: absorbA,
            emissionRange: .pi * 0.6,
            scaleSpeed: -0.015,
            alphaSpeed: -0.6
        )
        let aGlow = makeCell(
            birth: 8,
            life: 0.7,
            vel: 8,
            scale: 0.022,
            color: softBlush.withAlphaComponent(0.18),
            image: Self.glowImg,
            emissionLong: absorbA,
            emissionRange: .pi * 0.5,
            scaleSpeed: -0.025,
            alphaSpeed: -0.9
        )
        let aSparkle = makeCell(
            birth: 8,
            life: 0.5,
            vel: 10,
            scale: 0.005,
            color: dustyRose.withAlphaComponent(0.4),
            image: Self.circleImg,
            emissionLong: absorbA,
            emissionRange: .pi * 0.4,
            scaleSpeed: -0.008,
            alphaSpeed: -1.2
        )
        vortexLayer.emitterCells = [aDust, aGlow, aSparkle]
    }

    private func makeCell(
        birth: Float,
        life: Float,
        vel: CGFloat,
        scale: CGFloat,
        color: UIColor,
        image: UIImage?,
        emissionLong: CGFloat = 0,
        emissionRange: CGFloat = .pi * 2,
        scaleSpeed: CGFloat = -0.001,
        alphaSpeed: Float = -0.04
    ) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.birthRate = birth
        c.lifetime = life
        c.lifetimeRange = life * 0.5
        c.velocity = vel
        c.velocityRange = vel * 2
        c.emissionRange = emissionRange
        c.emissionLongitude = emissionLong
        c.scale = scale
        c.scaleRange = scale * 0.6
        c.scaleSpeed = scaleSpeed
        c.alphaSpeed = alphaSpeed
        c.alphaRange = 0.15
        c.spin = .pi * 0.06
        c.spinRange = .pi * 0.25
        c.color = color.cgColor
        c.contents = image?.cgImage
        return c
    }

    private static let circleImg: UIImage? = {
        let s: CGFloat = 64
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: CGSize(width: s, height: s)))
        }
    }()

    private static let glowImg: UIImage? = {
        let s: CGFloat = 64
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { ctx in
            let c = CGPoint(x: s / 2, y: s / 2)
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(
                    g,
                    startCenter: c,
                    startRadius: 0,
                    endCenter: c,
                    endRadius: s / 2,
                    options: []
                )
            }
        }
    }()
}
