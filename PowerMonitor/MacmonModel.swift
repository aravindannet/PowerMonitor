import Foundation
import IOKit
import Observation

/// GPU core count from the GPU driver's registry entry, or nil if it can't be read.
nonisolated func gpuCoreCount() -> Int? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AGXAccelerator"))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    let value = IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)
    return (value?.takeRetainedValue() as? NSNumber)?.intValue
}

/// One CPU core as reported by macmon.
struct CoreReading: Identifiable, Equatable {
    let id: String        // "E0", "P3", ...
    let cluster: String   // "E" or "P"
    let active: Double    // 0...100
    let mhz: Int
}

// MARK: - macmon JSON (one object per line from `macmon pipe`)

nonisolated private struct MacmonCore: Decodable {
    let coreId: Int
    let activeRatio: Double
    let freqMhz: Int
}

nonisolated private struct MacmonSample: Decodable {
    let ecpuCores: [MacmonCore]?
    let pcpuCores: [MacmonCore]?
    let ecpuActiveRatio: Double?
    let ecpuFreqMhz: Int?
    let pcpuActiveRatio: Double?
    let pcpuFreqMhz: Int?
    let gpuActiveRatio: Double?
    let gpuFreqMhz: Int?
    let cpuPower: Double?
    let gpuPower: Double?
    let anePower: Double?
    let ramPower: Double?
    let sysPower: Double?
    let temp: Temp?
    let memory: Memory?
    let fans: [Fan]?

    struct Temp: Decodable { let cpuTempAvg: Double?; let gpuTempAvg: Double? }
    struct Memory: Decodable { let ramTotal: Int64?; let ramUsage: Int64?; let swapTotal: Int64?; let swapUsage: Int64? }
    struct Fan: Decodable { let rpm: Int?; let maxRpm: Int? }
}

nonisolated private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
}()

/// Power draw by component at one moment, in watts.
nonisolated struct ComponentSample: Equatable {
    var cpu = 0.0, gpu = 0.0, ane = 0.0, ram = 0.0, other = 0.0
    var total: Double { cpu + gpu + ane + ram + other }
}

/// Runs `macmon pipe` and publishes its readings for SwiftUI.
@Observable
@MainActor
final class MacmonModel {
    var status = "Starting macmon..."
    var isLive = false

    var cores: [CoreReading] = []
    /// GPU cores on this Mac, read once at launch. Zero if unknown.
    var gpuCores = 0
    var eActive = 0.0
    var pActive = 0.0
    var gpuActive = 0.0
    var eMHz = 0
    var pMHz = 0
    var gpuMHz = 0

    var cpuW = 0.0
    var gpuW = 0.0
    var aneW = 0.0
    var ramW = 0.0
    var systemW = 0.0
    var cpuTemp = 0.0
    var gpuTemp = 0.0
    var ramUsedGB = 0.0
    var ramTotalGB = 0.0
    var swapGB = 0.0
    var fanRPM = 0
    var fanMaxRPM = 0

    /// Power by component, last 90 seconds, for the stacked graph.
    var componentHistory: [ComponentSample] = []
    /// Busiest apps by CPU, refreshed every two seconds.
    var topApps: [ProcessUsage] = []

    var totalW: Double { cpuW + gpuW + aneW }
    var otherW: Double { max(0, systemW - cpuW - gpuW - aneW - ramW) }

    private var process: Process?
    private var appsTask: Task<Void, Never>?

    func start() {
        guard process == nil else { return }
        guard let path = ["/opt/homebrew/bin/macmon", "/usr/local/bin/macmon"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            status = "macmon not found. Run: brew install macmon"
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["pipe", "-i", "1000"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.terminationHandler = { _ in
            Task { @MainActor in
                self.isLive = false
                self.status = "macmon stopped"
            }
        }

        do {
            try proc.run()
        } catch {
            status = "Could not start macmon: \(error.localizedDescription)"
            return
        }
        process = proc
        isLive = true
        gpuCores = gpuCoreCount() ?? 0
        status = "Live · macmon"
        appsTask = Task { [weak self] in
            while !Task.isCancelled {
                let apps = await ProcessSampler.top(limit: 6)
                self?.topApps = apps
                try? await Task.sleep(for: .seconds(2))
            }
        }

        let handle = pipe.fileHandleForReading
        Task.detached {
            do {
                for try await line in handle.bytes.lines {
                    guard let data = line.data(using: .utf8),
                          let sample = try? decoder.decode(MacmonSample.self, from: data) else { continue }
                    await MainActor.run { self.apply(sample) }
                }
            } catch {
                // The pipe closed or failed; the termination handler reports it.
            }
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        appsTask?.cancel()
        appsTask = nil
    }

    private func apply(_ s: MacmonSample) {
        let e = (s.ecpuCores ?? []).map { CoreReading(id: "E\($0.coreId)", cluster: "E",
                                                      active: $0.activeRatio * 100, mhz: $0.freqMhz) }
        let p = (s.pcpuCores ?? []).map { CoreReading(id: "P\($0.coreId)", cluster: "P",
                                                      active: $0.activeRatio * 100, mhz: $0.freqMhz) }
        cores = e + p

        eActive = (s.ecpuActiveRatio ?? 0) * 100
        pActive = (s.pcpuActiveRatio ?? 0) * 100
        gpuActive = (s.gpuActiveRatio ?? 0) * 100
        eMHz = s.ecpuFreqMhz ?? 0
        pMHz = s.pcpuFreqMhz ?? 0
        gpuMHz = s.gpuFreqMhz ?? 0

        cpuW = s.cpuPower ?? 0
        gpuW = s.gpuPower ?? 0
        aneW = s.anePower ?? 0
        ramW = s.ramPower ?? 0
        systemW = s.sysPower ?? 0

        cpuTemp = s.temp?.cpuTempAvg ?? 0
        gpuTemp = s.temp?.gpuTempAvg ?? 0

        let gb = 1_073_741_824.0
        ramUsedGB = Double(s.memory?.ramUsage ?? 0) / gb
        ramTotalGB = Double(s.memory?.ramTotal ?? 0) / gb
        swapGB = Double(s.memory?.swapUsage ?? 0) / gb

        fanRPM = s.fans?.first?.rpm ?? 0
        fanMaxRPM = s.fans?.first?.maxRpm ?? 0

        componentHistory.append(ComponentSample(cpu: cpuW, gpu: gpuW, ane: aneW, ram: ramW, other: otherW))
        if componentHistory.count > 90 { componentHistory.removeFirst(componentHistory.count - 90) }
    }
}
