# TypingResearch — iOS Typing Data Collector (V1 Hidden)

An iPhone app for HCI keyboard research. Collects keystroke-level typing data including tap coordinates, timing, and accuracy metrics from participants performing timed typing sessions.

## Features

- Custom QWERTY keyboard that matches the device's native keyboard dimensions
- Captures per-keypress tap coordinates (local x/y, normalized, screen position, key size)
- Continuous word stream — no phrase-by-phrase interruption
- Session timer starts on first keypress
- Export data as CSV or JSON via iOS share sheet

## Requirements

- iOS 17.0+
- Xcode 15+
- iPhone (tested on iPhone 16)

## Build & Run

```sh
open TypingResearch.xcodeproj
```

Select your device or simulator, then build and run. For a physical device, set your team under **Signing & Capabilities**.

## Data Collection Flow

1. **Setup** — Enter participant info (name optional), dominant hand, session duration (15s / 30s / 45s / 1min / custom)
2. **Session** — Participant types a continuous stream of random words using the in-app keyboard
3. **Summary** — Session stats shown; export data via share sheet

## Exports

| Export | Contents |
|--------|----------|
| **Export CSV** | One row per trial — accuracy, WPM, chars/sec, backspace count |
| **Export JSON** | Full session + trial data in structured JSON |
| **Export Keystrokes CSV** | One row per keystroke — timestamp, key, tap coordinates, IKI, correctness |

### Keystrokes CSV columns

`trial_id`, `timestamp`, `event_type`, `replacement_string`, `range_start`, `range_length`, `text_before`, `text_after`, `expected_index`, `expected_char`, `actual_char`, `is_correct`, `inter_key_interval_ms`, `tap_local_x`, `tap_local_y`, `tap_norm_x`, `tap_norm_y`, `key_label`, `key_screen_x`, `key_screen_y`, `key_width`, `key_height`

`tap_norm_x` / `tap_norm_y` are normalized 0–1 within the key, suitable for cross-device heatmap analysis.

## Project Structure

```
TypingResearch/
├── Models/
│   └── Models.swift          # SwiftData models (Participant, Session, Trial, InputEvent)
├── ViewModels/
│   └── SessionManager.swift  # @Observable session state machine
├── Views/
│   ├── ParticipantSetupView.swift
│   ├── SessionView.swift
│   ├── TrialView.swift
│   └── CustomKeyboardView.swift
├── Services/
│   └── DataExporter.swift    # CSV + JSON export
└── Utilities/
    └── Utilities.swift       # DeviceInfo, WordGenerator, MetricsComputer
```
