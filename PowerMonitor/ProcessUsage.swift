import Foundation
import AppKit

/// One app's share of the CPU and memory, summed over its helper processes.
nonisolated struct ProcessUsage: Identifiable, Equatable {
    let id: String      // app name, e.g. "Google Chrome"
    let cpu: Double     // percent of one core, as `ps` reports it (can exceed 100)
    let memMB: Double
}

/// Reads the busiest apps from `ps`. Needs no admin rights.
nonisolated enum ProcessSampler {
    static func top(limit: Int) async -> [ProcessUsage] {
        await Task.detached(priority: .utility) { () -> [ProcessUsage] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/ps")
            proc.arguments = ["-axo", "pcpu=,rss=,comm="]
            let pipe = Pipe()
            proc.standardOutput = pipe
            do { try proc.run() } catch { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return [] }

            var totals: [String: (cpu: Double, rssKB: Double)] = [:]
            for line in text.split(separator: "\n") {
                let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                guard parts.count == 3, let cpu = Double(parts[0]), let rss = Double(parts[1]) else { continue }
                let name = appName(from: String(parts[2]))
                let current = totals[name, default: (0, 0)]
                totals[name] = (current.cpu + cpu, current.rssKB + rss)
            }
            return totals
                .map { ProcessUsage(id: $0.key, cpu: $0.value.cpu, memMB: $0.value.rssKB / 1024) }
                .filter { $0.cpu >= 0.1 }
                .sorted { $0.cpu > $1.cpu }
                .prefix(limit)
                .map { $0 }
        }.value
    }

    /// "/Applications/Google Chrome.app/.../Google Chrome Helper" -> "Google Chrome"
    static func appName(from path: String) -> String {
        if let bundle = path.split(separator: "/").first(where: { $0.hasSuffix(".app") }) {
            return String(bundle.dropLast(4))
        }
        return path.split(separator: "/").last.map(String.init) ?? path
    }
}

/// Quits a running app politely, the same as choosing Quit from its menu.
/// The app can still ask to save unsaved work before it closes.
enum AppQuitter {
    @MainActor
    static func regularApp(named name: String) -> NSRunningApplication? {
        guard name != "PowerMonitor" else { return nil }
        // Match on the bundle file name (e.g. "iTerm.app"), since macOS's display name can differ.
        return NSWorkspace.shared.runningApplications.first {
            $0.activationPolicy == .regular && $0.bundleURL?.lastPathComponent == "\(name).app"
        }
    }

    @MainActor
    static func quit(named name: String) {
        regularApp(named: name)?.terminate()
    }
}
