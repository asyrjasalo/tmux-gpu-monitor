# Tmux GPU Monitor

A lightweight tmux plugin that displays GPU usage in the tmux status bar — pure shell, no Python required.

## Supported Platforms

| Platform | Method |
|----------|--------|
| macOS (Apple Silicon) | [`macmon`](https://github.com/vladkens/macmon) CLI (sudoless) |
| Linux (NVIDIA) | `nvidia-smi` |
| Linux (AMD) | `/sys/class/drm/card*/device/gpu_busy_percent` |
| Other | Prints empty string |

## Installation

### Install with [TPM](https://github.com/tmux-plugins/tpm)

Add the plugin to your tmux config:

```bash
set -g @plugin 'asyrjasalo/tmux-gpu-monitor'
```

Then press `Prefix + I` to install.

### Manual

Clone this repo somewhere and add it to your tmux config:

```bash
run-shell /path/to/tmux-gpu-monitor/gpu-monitor.tmux
```

## Usage

The plugin provides the `#{gpu}` placeholder for use in `status-right` and `status-left`:

```bash
set -g status-right "#{gpu}"
```

### Options

- `-i <seconds>` — sampling interval (default: `1`). Only affects macOS (`macmon -i`).

```bash
set -g status-right "#{gpu -i 2}"
```

## Dependencies

- **macOS**: [`macmon`](https://github.com/vladkens/macmon) and [`jq`](https://jqlang.github.io/jq/)
- **Linux NVIDIA**: `nvidia-smi` (bundled with NVIDIA drivers)
- **Linux AMD**: No additional dependencies (reads sysfs)
