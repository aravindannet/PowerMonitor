import SwiftUI

/// A colour with alpha that follows the Mac's light or dark appearance.
func clayColor(light: (CGFloat, CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat, CGFloat)) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let c = isDark ? dark : light
        return NSColor(red: c.0, green: c.1, blue: c.2, alpha: c.3)
    })
}

/// A colour that follows the Mac's light or dark appearance.
func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let c = isDark ? dark : light
        return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    })
}

/// Colours used across the app, matching the browser dashboard.
enum Style {
    static let clayCard = clayColor(light: (0.96, 0.97, 1.00, 1), dark: (0.15, 0.17, 0.26, 1))
    static let clayShadowDark = clayColor(light: (0.64, 0.67, 0.80, 0.55), dark: (0.00, 0.00, 0.00, 0.60))
    static let clayShadowLight = clayColor(light: (1.00, 1.00, 1.00, 0.95), dark: (0.35, 0.38, 0.52, 0.30))
    static let clayRim = clayColor(light: (1.00, 1.00, 1.00, 0.70), dark: (1.00, 1.00, 1.00, 0.06))
    static let windowTop = adaptive(light: (0.78, 0.84, 1.00), dark: (0.13, 0.14, 0.20))
    static let windowBottom = adaptive(light: (0.90, 0.80, 0.98), dark: (0.11, 0.12, 0.17))
    static let blobCool = adaptive(light: (0.66, 0.70, 1.00), dark: (0.20, 0.19, 0.36))
    static let blobWarm = adaptive(light: (1.00, 0.74, 0.86), dark: (0.30, 0.17, 0.26))
    static let ink = adaptive(light: (0.12, 0.13, 0.16), dark: (0.85, 0.87, 0.90))
    static let muted = adaptive(light: (0.40, 0.43, 0.49), dark: (0.50, 0.53, 0.58))
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

/// A claymorphic card: soft rounded shape with a light rim and a shadow on each side.
struct Panel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Style.muted)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ClayShape(radius: 28))
    }
}

/// The clay surface itself, drawn as a background so only the shape casts shadows, not the text.
struct ClayShape: View {
    let radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Style.clayCard)
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Style.clayRim, lineWidth: 1.5))
            .shadow(color: Style.clayShadowDark, radius: 12, x: 8, y: 10)
            .shadow(color: Style.clayShadowLight, radius: 10, x: -7, y: -7)
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

/// Stacked graph of power by component over time: what is drawing, and how much.
struct StackedHistory: View {
    let samples: [ComponentSample]
    let maxValue: Double

    private let layers: [(name: String, colour: Color, value: (ComponentSample) -> Double)] = [
        ("CPU", Style.cpu, { $0.cpu }),
        ("GPU", Style.gpu, { $0.gpu }),
        ("ANE", Style.ane, { $0.ane }),
        ("RAM", Style.ram, { $0.ram }),
        ("Other", Color(white: 0.45), { $0.other }),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { ctx, size in
                // Graticule
                var grid = Path()
                for i in 1..<4 {
                    let y = size.height * CGFloat(i) / 4
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 1)

                guard samples.count > 1 else { return }
                let n = samples.count
                func point(_ i: Int, _ watts: Double) -> CGPoint {
                    CGPoint(x: size.width * CGFloat(i) / CGFloat(n - 1),
                            y: size.height - (size.height * CGFloat(min(watts, maxValue) / maxValue)))
                }
                // Stack each layer on top of the ones below it
                var base = [Double](repeating: 0, count: n)
                for layer in layers {
                    var top = base
                    for i in 0..<n { top[i] = base[i] + layer.value(samples[i]) }
                    var path = Path()
                    for i in 0..<n {
                        let p = point(i, top[i])
                        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    for i in (0..<n).reversed() { path.addLine(to: point(i, base[i])) }
                    path.closeSubpath()
                    ctx.fill(path, with: .color(layer.colour.opacity(0.85)))
                    base = top
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Style.screen))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Current watts per component
            let latest = samples.last ?? ComponentSample()
            ForEach(layers, id: \.name) { layer in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(layer.colour).frame(width: 9, height: 9)
                    Text(layer.name)
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(Style.muted)
                    Spacer()
                    Text(String(format: "%.2f W", layer.value(latest)))
                        .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Style.ink)
                        .monospacedDigit()
                }
            }
        }
    }
}

/// The apps using the most CPU right now, with memory.
struct TopAppsList: View {
    let apps: [ProcessUsage]
    @State private var toQuit: ProcessUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if apps.isEmpty {
                Text("Reading processes…")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Style.muted)
            }
            let top = max(1, apps.map(\.cpu).max() ?? 1)
            ForEach(apps) { app in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(app.id)
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(Style.ink)
                            .lineLimit(1).truncationMode(.tail)
                        Spacer()
                        if AppQuitter.regularApp(named: app.id) != nil {
                            Button("Quit") { toQuit = app }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Style.red)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Style.red.opacity(0.12)))
                        }
                        Text(String(format: "%.0f%% CPU", app.cpu))
                            .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Style.ink)
                    }
                    HStack(spacing: 8) {
                        MeterBar(fraction: app.cpu / top, colour: Style.perf)
                        Text(app.memMB >= 1024 ? String(format: "%.1f GB", app.memMB / 1024) : String(format: "%.0f MB", app.memMB))
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(Style.muted)
                            .frame(width: 58, alignment: .trailing)
                    }
                }
            }
            Spacer(minLength: 0)
            Text("GPU use by app needs admin rights, so it isn't shown.")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(Style.muted)
        }
        .confirmationDialog("Quit \(toQuit?.id ?? "this app")?",
                            isPresented: Binding(get: { toQuit != nil }, set: { if !$0 { toQuit = nil } }),
                            titleVisibility: .visible) {
            Button("Quit \(toQuit?.id ?? "")", role: .destructive) {
                if let app = toQuit { AppQuitter.quit(named: app.id) }
                toQuit = nil
            }
            Button("Cancel", role: .cancel) { toQuit = nil }
        } message: {
            Text("Quitting frees its memory. The app may ask you to save unsaved work first.")
        }
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
