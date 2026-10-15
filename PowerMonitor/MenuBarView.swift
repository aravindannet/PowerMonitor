import SwiftUI
import AppKit
import ServiceManagement

/// The power readings the menu bar item draws, as plain values.
struct PowerSnapshot {
    var total = 0.0, cpu = 0.0, gpu = 0.0, ane = 0.0, ram = 0.0, other = 0.0
}

/// Purple CPU, pink GPU, blue ANE, yellow RAM and grey other, as in the main window,
/// with the wattage printed over it.
struct PowerBreakdownBar: View {
    let snapshot: PowerSnapshot

    var body: some View {
        let parts: [(Double, Color)] = [(snapshot.cpu, Style.cpu), (snapshot.gpu, Style.gpu),
                                        (snapshot.ane, Style.ane), (snapshot.ram, Style.ram),
                                        (snapshot.other, Color(white: 0.45))]
        let total = max(0.01, parts.reduce(0) { $0 + $1.0 })
        ZStack {
            Rectangle().fill(Color(white: 0.15))
                .frame(width: 96, height: 18)
            HStack(spacing: 0) {
                ForEach(0..<parts.count, id: \.self) { i in
                    Rectangle().fill(parts[i].1)
                        .frame(width: 96 * CGFloat(parts[i].0 / total))
                }
            }
            .frame(width: 96, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.4), lineWidth: 0.5))

            Text("⚡ \(String(format: "%.1f W", snapshot.total))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 1.5)
        }
        .frame(width: 96, height: 18)
    }
}

/// Popup shown from the menu bar item, styled as a piece of studio hardware.
struct MenuBarView: View {
    let model: MacmonModel
    @State private var startsAtLogin = false

    private let plateText = Color(white: 0.90)
    private let plateMuted = Color(white: 0.55)

    var body: some View {
        VStack(spacing: 14) {
            header

            AnalogMeter(value: model.totalW, maxValue: 40)
                .frame(height: 170)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f W", model.totalW))
                            .font(.system(size: 26, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color(red: 0.23, green: 0.18, blue: 0.06))
                        Text("combined CPU + GPU + ANE")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(red: 0.23, green: 0.18, blue: 0.06).opacity(0.7))
                    }
                    .padding(.leading, 10)
                    .padding(.bottom, 6)
                }

            HStack(spacing: 8) {
                LCD(label: "CPU", value: String(format: "%.1f W", model.cpuW))
                LCD(label: "GPU", value: String(format: "%.1f W", model.gpuW))
                LCD(label: "ANE", value: String(format: "%.1f W", model.aneW))
                LCD(label: "SYSTEM", value: String(format: "%.1f W", model.systemW))
            }

            faders

            gpuStrip

            HStack(spacing: 8) {
                LCD(label: "CPU TEMP", value: String(format: "%.0f °C", model.cpuTemp))
                LCD(label: "GPU TEMP", value: String(format: "%.0f °C", model.gpuTemp))
                LCD(label: "MEMORY USED", value: String(format: "%.1f GB", model.ramUsedGB))
            }

            buttons
        }
        .padding(18)
        .frame(width: 440)
        .background(plate)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 8) {
            Text("MAC POWER")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(plateText)
            Text("MONITOR")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(plateMuted)
            Spacer()
            Circle()
                .fill(model.isLive ? Style.green : Style.red)
                .frame(width: 9, height: 9)
                .shadow(color: model.isLive ? Style.green : Style.red, radius: 5)
        }
    }

    private var faders: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                fader(model.eActive / 100, Style.eff, String(format: "%.0f%%", model.eActive), "EFF")
                fader(model.pActive / 100, Style.perf, String(format: "%.0f%%", model.pActive), "PERF")
                fader(model.gpuActive / 100, Style.gpu, String(format: "%.0f%%", model.gpuActive), "GPU")
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(.white.opacity(0.12)).frame(width: 1).padding(.horizontal, 10)

            HStack(alignment: .bottom, spacing: 12) {
                fader(model.cpuW / 40, Style.cpu, String(format: "%.1f", model.cpuW), "CPU W")
                fader(model.gpuActive / 100, Style.gpu, String(format: "%.0f%%", model.gpuActive), "GPU")
                fader(model.aneW / 40, Style.ane, String(format: "%.1f", model.aneW), "ANE W")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.black, lineWidth: 1))
    }

    private func fader(_ fraction: Double, _ colour: Color, _ value: String, _ name: String) -> some View {
        VStack(spacing: 6) {
            Fader(fraction: fraction, colour: colour, height: 120)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(plateText)
            Text(name)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(plateMuted)
        }
        .frame(maxWidth: .infinity)
    }

    /// One LED per GPU core, lit by the single GPU load macmon reports.
    private var gpuStrip: some View {
        let lit = Int((model.gpuActive / 100 * Double(model.gpuCores)).rounded())
        return VStack(alignment: .leading, spacing: 6) {
            Text("GPU · \(model.gpuCores) CORES · \(Int(model.gpuActive.rounded()))%")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(plateMuted)
            HStack(spacing: 3) {
                ForEach(0..<model.gpuCores, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < lit ? Style.gpu : Color(red: 0.16, green: 0.10, blue: 0.10))
                        .shadow(color: i < lit ? Style.gpu : .clear, radius: 3)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 22)
            .background(RoundedRectangle(cornerRadius: 8).fill(.black))
            .animation(.easeOut(duration: 0.3), value: lit)
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Toggle(isOn: Binding(get: { startsAtLogin }, set: setStartsAtLogin)) {
                Text("START AT LOGIN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(plateText)
            }
            .toggleStyle(.switch)
            .onAppear { startsAtLogin = SMAppService.mainApp.status == .enabled }

            HStack {
                Button("OPEN WINDOW") { AppController.showMainWindow() }
                    .buttonStyle(HardwareButtonStyle())
                Spacer()
                Button("HIDE") { AppController.hideMainWindow() }
                    .buttonStyle(HardwareButtonStyle())
            }
        }
    }

    private func setStartsAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Start at login change failed: \(error.localizedDescription)")
        }
        startsAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Dark brushed plate with a bezel and four screws.
    private var plate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(white: 0.21), Color(white: 0.12)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color(white: 0.02), lineWidth: 3))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.08), lineWidth: 1).padding(3))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
            VStack {
                HStack { screw; Spacer(); screw }
                Spacer()
                HStack { screw; Spacer(); screw }
            }
            .padding(8)
        }
    }

    private var screw: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(white: 0.55), Color(white: 0.20)],
                                 center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: 6))
            .frame(width: 9, height: 9)
            .overlay(Rectangle().fill(.black.opacity(0.5)).frame(width: 6, height: 1).rotationEffect(.degrees(40)))
    }
}

/// Raised metal key that dips when pressed.
struct HardwareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(Color(white: 0.12))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: pressed ? [Color(white: 0.62), Color(white: 0.72)]
                                                         : [Color(white: 0.90), Color(white: 0.66)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(pressed ? 0.2 : 0.5), radius: pressed ? 1 : 4, y: pressed ? 0 : 3)
            .offset(y: pressed ? 1 : 0)
    }
}
