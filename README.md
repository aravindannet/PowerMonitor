# PowerMonitor

A native macOS app that shows what your Apple silicon Mac is doing: total power draw, CPU and GPU load, per-core activity, frequencies, temperatures, memory, and fan speed. It's styled like a piece of studio hardware, with an analog power meter, rotary knobs, faders, and LED columns for each core.

It needs no admin password. It reads the chip's sensors through [macmon](https://github.com/vladkens/macmon).

## Features

- **Total power:** an analog meter for combined CPU + GPU + ANE watts, plus a readout for whole-system power.
- **Load:** knobs for CPU watts, GPU activity, and ANE watts.
- **Cluster faders:** efficiency, performance, and GPU activity.
- **Cores:** one LED column per core, grouped into efficiency and performance cores.
- **Power breakdown:** a stacked bar of CPU, GPU, ANE, RAM, and other power.
- **Frequencies and temperatures:** clock speeds for each core cluster and the GPU, plus CPU and GPU temperature.
- **Readouts:** memory used, swap used, and fan speed.
- **History:** a 90-second graph of total draw.

The app quits when you close its window, and the background sensor process stops with it.

## Requirements

- An Apple silicon Mac (M-series)
- macOS 27.0 or later
- Xcode 27 or later, to build from source
- [Homebrew](https://brew.sh), to install macmon

## Install macmon

```sh
brew install macmon
```

PowerMonitor looks for macmon in `/opt/homebrew/bin` and `/usr/local/bin`.

## Build and run

1. Clone the repo:
   ```sh
   git clone https://github.com/aravindannet/PowerMonitor.git
   cd PowerMonitor
   ```
2. Open `PowerMonitor.xcodeproj` in Xcode.
3. Select the **PowerMonitor** scheme and **My Mac** as the destination, then press **⌘R**.

To build from the command line:

```sh
xcodebuild -project PowerMonitor.xcodeproj -scheme PowerMonitor \
  -destination 'platform=macOS' build
```

To install it, copy the built `PowerMonitor.app` into `/Applications`.

## Project layout

| File | Purpose |
|---|---|
| `PowerMonitor/MyApp.swift` | App entry point. Quits when the last window closes. |
| `PowerMonitor/MacmonModel.swift` | Runs `macmon pipe`, decodes its JSON, and publishes the readings. |
| `PowerMonitor/Widgets.swift` | Drawn controls: meter, knobs, faders, LED columns, graph, LCD readouts. |
| `PowerMonitor/ContentView.swift` | The window layout. |
| `PowerMonitor/Assets.xcassets` | App icon and accent colour. |

## Troubleshooting

- **"macmon not found":** install it with `brew install macmon`, then reopen the app.
- **The window shows "macmon stopped":** macmon exited. Reopen the app. If it keeps happening, run `macmon pipe` in Terminal to see the error.
- **Readings are empty in an Xcode build:** App Sandbox blocks the app from starting macmon. Open the target's **Signing & Capabilities** tab and remove **App Sandbox**.

## Notes

- Values come from macmon, which reads undocumented Apple sensor interfaces. Figures can differ slightly from Apple's own tools, and a future macOS update could change what macmon can read.
- The GPU and memory readings follow what macOS reports. "Memory used" includes cache, so it's higher than the memory apps actively use.

## Credits

- [macmon](https://github.com/vladkens/macmon) by vladkens provides the sensor data.
