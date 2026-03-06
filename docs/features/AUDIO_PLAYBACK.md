# Audio Playback

ReaderPro provides in-app audio playback with waveform visualization, auto-play, and speed control.

## Architecture

```
ProjectDetailView
    └── audioSection
         ├── WaveformView (visual)
         ├── PlaybackControlsView (buttons)
         └── Speed selector (0.75x–2.0x)

EditorPresenter
    └── AudioPlayerPort (protocol)
         └── AVAudioPlayerAdapter (implementation)
```

## AVAudioPlayerAdapter

Implements `AudioPlayerPort` using `AVAudioPlayer`.

**Properties:**
- `isPlaying: Bool` — current playback state
- `currentTime: TimeInterval` — current position
- `duration: TimeInterval` — total duration
- `rate: Float` — playback speed

**Methods:**

| Method | Description |
|---|---|
| `load(path:)` | Load WAV file, prepare for playback |
| `play()` | Start or resume playback |
| `pause()` | Pause playback |
| `stop()` | Stop and reset to beginning |
| `seek(to:)` | Jump to specific time |
| `setRate(_:)` | Set playback speed (0.5–2.0) |
| `generateWaveformSamples(sampleCount:)` | Generate amplitude data for visualization |

## Playback Controls

### PlaybackControlsView

Stateless component with callbacks:

```
  00:15    ⏪10s    ▶/⏸    ⏩10s    01:30
```

- **Play/Pause** — toggle playback
- **Skip backward** — 10 seconds back
- **Skip forward** — 10 seconds forward
- **Time display** — current position and total duration

### Speed Selector

Preset buttons: `0.75x`, `1.0x`, `1.25x`, `1.5x`, `2.0x`

Uses `AVAudioPlayer.enableRate = true` for variable-speed playback.

## Waveform Visualization

### WaveformView

Canvas-based amplitude display with seek support.

**Rendering:**
- Vertical bars representing audio amplitude
- Played portion: `appHighlight` color
- Unplayed portion: `appTertiary` with 0.4 opacity
- Progress line: vertical indicator at current position
- Height: 80pt

**Interaction:**
- `DragGesture` for seeking
- Calculates progress (0.0–1.0) from gesture position
- Calls `onSeek` callback to update playback position

**Sample Generation:**
The adapter reads the audio file via `AVAudioFile`, extracts PCM buffer samples, and computes peak amplitudes per bucket.

## Auto-Play

When enabled, the player automatically advances to the next entry after the current one finishes.

**Flow:**
1. `AVAudioPlayerDelegate.audioPlayerDidFinishPlaying()` fires
2. Calls `onPlaybackComplete` callback
3. `EditorPresenter.handlePlaybackCompletion()` checks if auto-play is enabled
4. If enabled, loads and plays the next entry in sequence
5. If last entry reached, stops playback

**Toggle:** Located in the audio section of ProjectDetailView.

## Entry Navigation

- **Previous/Next buttons** — Navigate between entries
- Current entry highlighted in grid with border + scale animation
- Entry indicator shows `"Entry X of Y"` text

## Playback Update Timer

A timer runs during playback to update the ViewModel with current time and progress. Stops when playback pauses or ends.

```swift
private func startUpdateTimer() {
    updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        Task { @MainActor in self.updatePlaybackState() }
    }
}
```
