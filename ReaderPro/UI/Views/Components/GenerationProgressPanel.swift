import SwiftUI

/// Bottom bar that shows generation progress.
/// Slides up from the bottom edge, full-width.
/// Supports collapsed (single row) and expanded (with logs) modes.
struct GenerationProgressPanel: View {

    @ObservedObject var manager: GenerationManager

    var body: some View {
        if manager.isPanelVisible, let job = manager.activeJob {
            VStack(spacing: 0) {
                Spacer()

                if manager.isPanelExpanded {
                    expandedPanel(job: job)
                } else {
                    collapsedBar(job: job)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: manager.isPanelVisible)
            .animation(.easeInOut(duration: 0.2), value: manager.isPanelExpanded)
        }
    }

    // MARK: - Collapsed Bar (single row)

    private func collapsedBar(job: GenerationJob) -> some View {
        VStack(spacing: 0) {
            // Top border accent
            Rectangle()
                .fill(progressColor(for: job))
                .frame(height: 2)

            HStack(spacing: 12) {
                // Status indicator
                statusIcon(for: job)

                // Project name + status
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.projectName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(1)

                    Text(job.statusMessage)
                        .font(.caption2)
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Token-level detail (e.g. "42% 504/1200 [00:32<01:12, 9.66tokens/s]")
                if !job.detailMessage.isEmpty && !job.status.isTerminal {
                    Text(job.detailMessage)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.appHighlight)
                        .lineLimit(1)
                }

                // Elapsed time
                Text(job.elapsedFormatted)
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
                    .monospacedDigit()

                // Expand button
                Button {
                    withAnimation { manager.isPanelExpanded = true }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }
                .buttonStyle(.plain)

                // Cancel/Dismiss
                terminalOrCancelButton(job: job)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.appSecondary)
    }

    // MARK: - Expanded Panel (with logs)

    private func expandedPanel(job: GenerationJob) -> some View {
        VStack(spacing: 0) {
            // Top border accent
            Rectangle()
                .fill(progressColor(for: job))
                .frame(height: 2)

            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack {
                    statusIcon(for: job)

                    Text(job.projectName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Elapsed + ETA
                    HStack(spacing: 8) {
                        Label(job.elapsedFormatted, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(Color.appTextSecondary)
                            .monospacedDigit()

                        if let eta = job.etaFormatted {
                            Text("ETA: \(eta)")
                                .font(.caption)
                                .foregroundColor(Color.appTextSecondary)
                                .monospacedDigit()
                        }
                    }

                    // Collapse button
                    Button {
                        withAnimation { manager.isPanelExpanded = false }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(Color.appTextSecondary)
                    }
                    .buttonStyle(.plain)

                    terminalOrCancelButton(job: job)
                }

                // Progress bar
                if let progress = job.progress {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(progressColor(for: job))
                } else if !job.status.isTerminal {
                    ProgressView()
                        .progressViewStyle(.linear)
                }

                // Status message + live detail
                HStack {
                    Text(job.statusMessage)
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)

                    Spacer()

                    if !job.detailMessage.isEmpty && !job.status.isTerminal {
                        Text(job.detailMessage)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.appHighlight)
                            .lineLimit(1)
                    }
                }

                // Log panel
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(job.logs) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(formatTimestamp(entry.timestamp))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(Color.appTextMuted)

                                    Text(entry.message)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(logColor(for: entry.level))
                                        .textSelection(.enabled)
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(8)
                    }
                    .frame(minHeight: 80, maxHeight: 160)
                    .background(Color.appPrimary)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.appTertiary.opacity(0.5), lineWidth: 1)
                    )
                    .onChange(of: job.logs.count) { _ in
                        if let lastEntry = job.logs.last {
                            withAnimation {
                                proxy.scrollTo(lastEntry.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.appSecondary)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func terminalOrCancelButton(job: GenerationJob) -> some View {
        if job.status.isTerminal {
            Button {
                withAnimation { manager.dismissPanel() }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                manager.cancelCurrentJob()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func statusIcon(for job: GenerationJob) -> some View {
        switch job.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.body)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.body)
        case .cancelled:
            Image(systemName: "slash.circle.fill")
                .foregroundColor(Color.appTextMuted)
                .font(.body)
        default:
            CircularProgressView(progress: job.progress)
        }
    }

    private func progressColor(for job: GenerationJob) -> Color {
        switch job.status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return Color.appTextMuted
        default: return Color.appHighlight
        }
    }

    private func logColor(for level: GenerationLogLevel) -> Color {
        switch level {
        case .info: return Color.appTextSecondary
        case .success: return .green
        case .warning: return Color.appHighlight
        case .error: return .red
        }
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Circular Progress View

/// Small circular progress indicator used in the collapsed bar
struct CircularProgressView: View {
    let progress: Double?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appTertiary, lineWidth: 2)
                .frame(width: 18, height: 18)

            if let progress = progress {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.appHighlight, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.appHighlight, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear { startSpinning() }
            }
        }
    }

    @State private var rotationAngle: Double = 0

    private func startSpinning() {
        withAnimation(
            .linear(duration: 1.0)
            .repeatForever(autoreverses: false)
        ) {
            rotationAngle = 360
        }
    }
}
