import SwiftUI

/// Colours used across the app, matching the browser dashboard.
enum Style {
    static let panelTop = Color(red: 0.17, green: 0.19, blue: 0.22)
    static let panelBottom = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let ink = Color(red: 0.85, green: 0.87, blue: 0.90)
    static let muted = Color(red: 0.50, green: 0.53, blue: 0.58)
    static let screen = Color(red: 0.03, green: 0.07, blue: 0.05)
    static let phosphor = Color(red: 0.36, green: 1.0, blue: 0.60)
    static let cpu = Color(red: 0.62, green: 0.55, blue: 1.0)
    static let gpu = Color(red: 1.0, green: 0.48, blue: 0.64)
    static let ane = Color(red: 0.42, green: 0.77, blue: 1.0)
    static let eff = Color(red: 0.25, green: 0.88, blue: 0.71)
    static let perf = Color(red: 0.62, green: 0.55, blue: 1.0)
    static let ram = Color(red: 0.90, green: 0.78, blue: 0.42)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.19)
    static let red = Color(red: 1.0, green: 0.30, blue: 0.30)
    static let green = Color(red: 0.22, green: 1.0, blue: 0.48)
}

/// A brushed-metal panel with four corner screws.
struct Panel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(Style.muted)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Style.panelTop, Style.panelBottom], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        .overlay(alignment: .topLeading) { Screw().padding(8) }
        .overlay(alignment: .topTrailing) { Screw().padding(8) }
        .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
    }
}

private struct Screw: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(white: 0.85), Color(white: 0.4), Color(white: 0.17)],
                                 center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: 6))
            .frame(width: 8, height: 8)
    }
}

/// Analog meter face with a needle. `value` runs 0...`maxValue`.
struct AnalogMeter: View {
    let value: Double
    let maxValue: Double
    private let sweep = 140.0   // degrees, centred on straight up

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let pivot = CGPoint(x: w / 2, y: h * 0.9)
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.96, blue: 0.84), Color(red: 0.85, green: 0.78, blue: 0.60)],
                                         center: UnitPoint(x: 0.5, y: 1.1), startRadius: 0, endRadius: w * 0.7))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(white: 0.1), lineWidth: 6))

                // Tick marks and numbers, drawn once around the pivot
                Canvas { ctx, size in
                    let ink = Color(red: 0.23, green: 0.18, blue: 0.06)
                    for mark in stride(from: 0.0, through: maxValue, by: 5.0) {
                        let a = angleRad(mark)
                        let major = Int(mark) % 10 == 0
                        let outer = CGPoint(x: pivot.x + CGFloat(sin(a)) * h * 0.78, y: pivot.y - CGFloat(cos(a)) * h * 0.78)
                        let inner = CGPoint(x: pivot.x + CGFloat(sin(a)) * h * (major ? 0.64 : 0.70), y: pivot.y - CGFloat(cos(a)) * h * (major ? 0.64 : 0.70))
                        var tick = Path(); tick.move(to: inner); tick.addLine(to: outer)
                        ctx.stroke(tick, with: .color(ink), lineWidth: major ? 2 : 1)
                        if major {
                            let label = Text("\(Int(mark))").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(ink)
                            let pos = CGPoint(x: pivot.x + CGFloat(sin(a)) * h * 0.48, y: pivot.y - CGFloat(cos(a)) * h * 0.48)
                            ctx.draw(label, at: pos, anchor: .center)
                        }
                    }
                }

                // Needle: a bar anchored at the pivot and rotated by the reading
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.23, blue: 0.18), Color(red: 0.48, green: 0.05, blue: 0.03)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: h * 0.78)
                    .offset(y: -h * 0.39)
                    .rotationEffect(.degrees(angleDeg(value)))
                    .position(pivot)
                    .animation(.spring(response: 0.7, dampingFraction: 0.75), value: value)
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.45), Color(white: 0.07)],
                                         center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: 9))
                    .frame(width: 16, height: 16)
                    .position(pivot)
            }
        }
        .aspectRatio(2.0, contentMode: .fit)
        .shadow(color: .black.opacity(0.5), radius: 8, y: 5)
    }

    private func angleDeg(_ v: Double) -> Double {
        let fraction = min(1, max(0, v / maxValue))
        return -sweep / 2 + sweep * fraction
    }

    private func angleRad(_ v: Double) -> Double {
        angleDeg(v) * .pi / 180
    }
}

/// Rotary knob. `fraction` 0...1 turns the pointer across a 270° sweep.
struct Knob: View {
    let fraction: Double
    let colour: Color

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.001))
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.45), Color(white: 0.18), Color(white: 0.08)],
                                     center: UnitPoint(x: 0.38, y: 0.32), startRadius: 2, endRadius: 60))
                .overlay(Circle().strokeBorder(Color(white: 0.02), lineWidth: 4))
                .shadow(color: .black.opacity(0.6), radius: 8, y: 6)
            Capsule()
                .fill(colour)
                .frame(width: 4, height: 30)
                .shadow(color: colour, radius: 5)
                .offset(y: -22)
                .rotationEffect(.degrees(-135 + 270 * min(1, max(0, fraction))))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fraction)
        }
    }
}

/// Vertical fader: slot with a cap that slides with `fraction`.
struct Fader: View {
    let fraction: Double
    let colour: Color
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            let capH: CGFloat = 22
            let travel = geo.size.height - capH
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 14)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.06)))
                    .frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.23)], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .center) { Rectangle().fill(colour).frame(height: 2).padding(.horizontal, 5).shadow(color: colour, radius: 4) }
                    .frame(width: 46, height: capH)
                    .shadow(color: .black.opacity(0.7), radius: 4, y: 3)
                    .offset(y: -travel * min(1, max(0, fraction)))
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: fraction)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
    }
}

/// One core as a column of eight lamps, lit in proportion to its load.
struct CoreLamps: View {
    let active: Double   // 0...100
    let label: String
    let mhz: Int

    var body: some View {
        let lit = Int((active / 12.5).rounded())
        VStack(spacing: 4) {
            VStack(spacing: 2) {
                ForEach((0..<8).reversed(), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < lit ? lampColour(i) : Color(red: 0.16, green: 0.10, blue: 0.10))
                        .frame(height: 6)
                        .shadow(color: i < lit ? lampColour(i) : .clear, radius: 4)
                }
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.05)))

            Text("\(Int(active.rounded()))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Style.ink)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Style.muted)
        }
        .animation(.easeOut(duration: 0.3), value: lit)
    }

    private func lampColour(_ i: Int) -> Color {
        i >= 6 ? Style.red : i >= 4 ? Style.amber : Style.green
    }
}

/// Horizontal bar with a rounded track.
struct MeterBar: View {
    let fraction: Double
    let colour: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.06)))
                Capsule().fill(colour)
                    .frame(width: max(4, geo.size.width * min(1, max(0, fraction))))
                    .shadow(color: colour.opacity(0.8), radius: 4)
                    .animation(.easeOut(duration: 0.6), value: fraction)
            }
        }
        .frame(height: 12)
    }
}

/// Phosphor-style line chart of recent power.
struct HistoryScope: View {
    let values: [Double]
    let maxValue: Double

    var body: some View {
        Canvas { ctx, size in
            // Graticule
            var grid = Path()
            for i in 1..<8 { grid.move(to: CGPoint(x: 0, y: size.height * CGFloat(i) / 8)); grid.addLine(to: CGPoint(x: size.width, y: size.height * CGFloat(i) / 8)) }
            for i in 1..<12 { grid.move(to: CGPoint(x: size.width * CGFloat(i) / 12, y: 0)); grid.addLine(to: CGPoint(x: size.width * CGFloat(i) / 12, y: size.height)) }
            ctx.stroke(grid, with: .color(Style.phosphor.opacity(0.12)), lineWidth: 1)

            guard values.count > 1 else { return }
            var line = Path()
            for (i, v) in values.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
                let y = size.height - 8 - (size.height - 16) * CGFloat(min(v, maxValue) / maxValue)
                if i == 0 { line.move(to: CGPoint(x: x, y: y)) } else { line.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.drawLayer { layer in
                layer.addFilter(.shadow(color: Style.phosphor, radius: 6))
                layer.stroke(line, with: .color(Style.phosphor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Style.screen))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black, lineWidth: 1))
    }
}

/// Small LCD readout.
struct LCD: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .opacity(0.7)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .monospacedDigit()
        }
        .foregroundStyle(Style.phosphor)
        .shadow(color: Style.phosphor.opacity(0.6), radius: 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Style.screen))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black, lineWidth: 1))
    }
}
