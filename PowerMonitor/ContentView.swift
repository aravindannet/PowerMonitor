import SwiftUI

struct ContentView: View {
    @State private var model = MacmonModel()

    var body: some View {
        VStack(spacing: 14) {
            header

            // Row 1: power, load, readouts
            HStack(spacing: 14) {
                Panel(title: "Total power") {
                    VStack(spacing: 12) {
                        AnalogMeter(value: model.totalW, maxValue: 40)
                            .frame(maxWidth: 240)
                        Text(String(format: "%.1f W", model.totalW))
                            .font(.system(size: 26, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Style.ink)
                        Text("combined CPU + GPU + ANE")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Style.muted)
                    }
                }
                Panel(title: "Load") {
                    HStack(spacing: 8) {
                        knobColumn(fraction: model.cpuW / 40, colour: Style.cpu,
                                   value: String(format: "%.1f", model.cpuW), name: "CPU W")
                        knobColumn(fraction: model.gpuActive / 100, colour: Style.gpu,
                                   value: String(format: "%.0f%%", model.gpuActive), name: "GPU")
                        knobColumn(fraction: model.aneW / 40, colour: Style.ane,
                                   value: String(format: "%.1f", model.aneW), name: "ANE W")
                    }
                }
                Panel(title: "Readouts") {
                    VStack(spacing: 10) {
                        LCD(label: "SYSTEM POWER", value: String(format: "%.1f W", model.systemW))
                        LCD(label: "CPU / GPU TEMP", value: String(format: "%.0f / %.0f °C", model.cpuTemp, model.gpuTemp))
                        LCD(label: "MEMORY USED", value: String(format: "%.1f / %.0f GB", model.ramUsedGB, model.ramTotalGB))
                        LCD(label: "SWAP USED", value: String(format: "%.1f GB", model.swapGB))
                    }
                }
            }
            .frame(height: 230)

            // Row 2: faders and cores
            HStack(spacing: 14) {
                Panel(title: "Cluster faders") {
                    HStack(alignment: .bottom, spacing: 18) {
                        faderColumn(fraction: model.eActive / 100, colour: Style.eff,
                                    value: String(format: "%.0f%%", model.eActive), name: "EFFICIENCY")
                        faderColumn(fraction: model.pActive / 100, colour: Style.perf,
                                    value: String(format: "%.0f%%", model.pActive), name: "PERFORMANCE")
                        faderColumn(fraction: model.gpuActive / 100, colour: Style.gpu,
                                    value: String(format: "%.0f%%", model.gpuActive), name: "GPU")
                    }
                }
                .frame(maxWidth: 360)

                Panel(title: "Cores") {
                    HStack(alignment: .top, spacing: 24) {
                        coreGroup(title: "Efficiency", prefix: "E", colour: Style.eff)
                        coreGroup(title: "Performance", prefix: "P", colour: Style.perf)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Row 3: breakdown, frequencies, history
            HStack(spacing: 14) {
                Panel(title: "Power breakdown") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(format: "%.1f W system", model.systemW))
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Style.ink)
                        powerStack
                        legend
                        fanRow
                            .padding(.top, 6)
                        Spacer(minLength: 0)
                    }
                }
                Panel(title: "Frequencies") {
                    VStack(spacing: 12) {
                        freqRow("EFFICIENCY", mhz: model.eMHz, max: 2100, colour: Style.eff)
                        freqRow("PERFORM.", mhz: model.pMHz, max: 4600, colour: Style.perf)
                        freqRow("GPU", mhz: model.gpuMHz, max: 1600, colour: Style.gpu)
                        tempRow("GPU TEMP", value: model.gpuTemp, colour: Style.amber)
                        tempRow("CPU TEMP", value: model.cpuTemp, colour: Color(red: 1, green: 0.48, blue: 0.36))
                        Spacer(minLength: 0)
                    }
                }
                Panel(title: "Top apps by CPU") {
                    TopAppsList(apps: model.topApps)
                }
                Panel(title: "Draw by component, 90 s") {
                    StackedHistory(samples: model.componentHistory, maxValue: 40)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 300)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 1100, minHeight: 880)
        .background(
            LinearGradient(colors: [Color(red: 0.23, green: 0.25, blue: 0.29), Color(red: 0.14, green: 0.15, blue: 0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .task { model.start() }
        .onDisappear { model.stop() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("MAC POWER").font(.system(size: 16, weight: .heavy, design: .monospaced)).tracking(4)
            Text("MONITOR").font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(2)
                .foregroundStyle(Style.muted)
            Spacer()
            Circle().fill(model.isLive ? Style.green : Style.red).frame(width: 10, height: 10)
                .shadow(color: model.isLive ? Style.green : Style.red, radius: 6)
            Text(model.status).font(.system(size: 12, design: .monospaced)).foregroundStyle(Style.muted)
        }
        .foregroundStyle(Style.ink)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Color(white: 0.29), Color(white: 0.17)], startPoint: .top, endPoint: .bottom)))
    }

    // MARK: - Pieces

    private func knobColumn(fraction: Double, colour: Color, value: String, name: String) -> some View {
        VStack(spacing: 8) {
            Knob(fraction: fraction, colour: colour).frame(width: 96, height: 96)
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(Style.ink)
            Text(name).font(.system(size: 10, design: .monospaced)).foregroundStyle(Style.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func faderColumn(fraction: Double, colour: Color, value: String, name: String) -> some View {
        VStack(spacing: 8) {
            Fader(fraction: fraction, colour: colour, height: 170)
            Text(value).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(Style.ink)
            Text(name).font(.system(size: 10, design: .monospaced)).foregroundStyle(Style.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func coreGroup(title: String, prefix: String, colour: Color) -> some View {
        let cores = model.cores.filter { $0.cluster == prefix }
        return VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.8)))
                .foregroundStyle(.black)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 12) {
                ForEach(cores) { core in
                    CoreLamps(active: core.active, label: core.id, mhz: core.mhz)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var powerStack: some View {
        let parts: [(Double, Color)] = [(model.cpuW, Style.cpu), (model.gpuW, Style.gpu),
                                        (model.aneW, Style.ane), (model.ramW, Style.ram), (model.otherW, Color(white: 0.33))]
        let total = max(0.01, parts.reduce(0) { $0 + $1.0 })
        return GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<parts.count, id: \.self) { i in
                    Rectangle().fill(parts[i].1)
                        .frame(width: geo.size.width * CGFloat(parts[i].0 / total))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
            .animation(.easeOut(duration: 0.6), value: total)
        }
        .frame(height: 22)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            legendItem("CPU", model.cpuW, Style.cpu)
            legendItem("GPU", model.gpuW, Style.gpu)
            legendItem("ANE", model.aneW, Style.ane)
            legendItem("RAM", model.ramW, Style.ram)
            legendItem("Other", model.otherW, Color(white: 0.33))
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(Style.muted)
    }

    private var fanRow: some View {
        HStack(spacing: 10) {
            Text("FAN")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Style.muted)
                .frame(width: 40, alignment: .leading)
            MeterBar(fraction: model.fanMaxRPM > 0 ? Double(model.fanRPM) / Double(model.fanMaxRPM) : 0,
                     colour: Style.ane)
            Text(model.fanRPM > 0 ? "\(model.fanRPM) rpm" : "--")
                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Style.ink)
                .frame(width: 84, alignment: .trailing)
        }
    }

    private func legendItem(_ name: String, _ watts: Double, _ colour: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(colour).frame(width: 9, height: 9)
            Text(name)
            Spacer()
            Text(String(format: "%.1f W", watts)).foregroundStyle(Style.ink).monospacedDigit()
        }
    }

    private func freqRow(_ name: String, mhz: Int, max: Double, colour: Color) -> some View {
        HStack(spacing: 10) {
            Text(name).font(.system(size: 11, design: .monospaced)).foregroundStyle(Style.muted)
                .frame(width: 84, alignment: .leading)
            MeterBar(fraction: Double(mhz) / max, colour: colour)
            Text(mhz > 0 ? String(format: "%.2f GHz", Double(mhz) / 1000) : "--")
                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Style.ink)
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func tempRow(_ name: String, value: Double, colour: Color) -> some View {
        HStack(spacing: 10) {
            Text(name).font(.system(size: 11, design: .monospaced)).foregroundStyle(Style.muted)
                .frame(width: 84, alignment: .leading)
            MeterBar(fraction: value / 100, colour: colour)
            Text(value > 0 ? String(format: "%.0f °C", value) : "--")
                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Style.ink)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

#Preview {
    ContentView()
}
