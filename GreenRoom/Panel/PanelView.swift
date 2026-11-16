import AVFoundation
import GreenRoomCore
import PanelKit
import SwiftUI

/// How tall the panel may get: the room below the menu bar on the screen it opens on.
@MainActor
@Observable
final class PanelFit {
    var maxHeight: CGFloat = .infinity
}

struct PanelView: View {
    let monitor: DeviceMonitor
    let checks: Checks
    let updater: Updater
    let fit: PanelFit
    let showHistory: () -> Void
    let closePanel: () -> Void
    let showRecordPreview: () -> Void
    let showSettings: () -> Void
    @State private var contentHeight: CGFloat?

    /// Scrolls only when the screen is too short for everything, like a teleprompter display.
    var body: some View {
        ScrollView {
            panel
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: Panel<EmptyView, EmptyView>.width, height: contentHeight.map { min($0, fit.maxHeight) })
    }

    private var panel: some View {
        Panel(accent: PanelAccent.greenRoom) {
            fascia
            StatusVerdict(
                check: monitor.readyCheck, setupName: monitor.setup?.name, proposed: monitor.proposedSetup,
                select: { monitor.select($0) }, ignore: { monitor.ignore(app: $0) }
            )
            ForEach(monitor.advisories, id: \.device.id) { advisory in
                AdvisoryCard(advisory: advisory) { monitor.select($0) }
            }
            if let failure = monitor.switchFailure {
                PanelNote(text: failure, caution: true)
            }
            cameraSection
            microphoneSection
            speakerSection
            if !monitor.missing.isEmpty {
                missingSection
            }
            if !monitor.flaky.isEmpty {
                flakySection
            }
            RecordingSection(monitor: monitor)
        } footer: {
            PanelFooter(monitor: monitor, updater: updater, closePanel: closePanel,
                        showHistory: showHistory, showSettings: showSettings)
        }
        .onChange(of: monitor.previewCamera) { checks.restartCamera() }
        .onChange(of: monitor.snapshot.active(.microphone)) { checks.restartMeter() }
        .onChange(of: monitor.snapshot.devices(.microphone)) { checks.restartCompare() }
    }

    // MARK: Camera

    /// The metal fascia: the live preview in a chrome bezel, the framing tip, and the camera's name.
    private var fascia: some View {
        Fascia(nameplate: "Frame", timestamp: monitor.setup.map { "\($0.name) setup" }, label: cameraLabel) {
            VStack(spacing: 8) {
                ChromeBezel {
                    cameraWindow
                }
                if let advice = checks.camera.advice {
                    TipStrip(text: advice)
                }
            }
        }
    }

    private var isPreviewing: Bool {
        checks.cameraAccess == .authorized && monitor.previewCamera != nil
    }

    private var cameraWindow: some View {
        ZStack {
            Color.black
            if isPreviewing {
                CameraPreview(session: checks.camera.session)
            } else {
                VStack(spacing: 8) {
                    Text(cameraMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    if cameraDenied {
                        Button("Open Settings") { PrivacySettings.open(.camera) }
                            .buttonStyle(MiniButtonStyle())
                            .environment(\.colorScheme, .dark)
                    }
                }
                .padding()
            }
        }
        .overlay(alignment: .topLeading) {
            if isPreviewing {
                TallyLight("Live").padding(7)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if monitor.previewCamera != nil {
                Button(action: showRecordPreview) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(7)
                .help("Record preview: the camera full screen, with your mic and speaker")
                .accessibilityLabel("Record preview")
            }
        }
    }

    private var cameraLabel: String {
        guard let camera = monitor.previewCamera else { return "No camera" }
        return "\(camera.name) · \(camera.transport.label)"
    }

    private var cameraDenied: Bool {
        !monitor.snapshot.devices(.camera).isEmpty
            && (checks.cameraAccess == .denied || checks.cameraAccess == .restricted)
    }

    private var cameraMessage: String {
        if monitor.snapshot.devices(.camera).isEmpty { return "No camera connected" }
        return cameraDenied ? "Allow camera access in System Settings › Privacy & Security" : "Starting camera…"
    }

    private var cameraSection: some View {
        DeviceSection(kind: .camera, monitor: monitor, selected: monitor.previewCamera)
    }

    // MARK: Microphone

    private var micDenied: Bool { checks.micAccess == .denied || checks.micAccess == .restricted }

    private var microphoneSection: some View {
        let canCompare = checks.micAccess == .authorized && monitor.snapshot.devices(.microphone).count > 1
        return VStack(spacing: 0) {
            DeviceSection(kind: .microphone, monitor: monitor, selected: monitor.snapshot.active(.microphone)) {
                if canCompare {
                    Button(checks.inputs.isOn ? "Done" : "Compare") { checks.toggleCompare() }
                        .buttonStyle(LinkButtonStyle())
                        .help("Shows a live level for every mic, so you can see which one hears you")
                }
            } detail: {
                if !micDenied {
                    LevelMeter(level: Double(checks.meter.level), segments: 12, cautionFrom: 9)
                        .accessibilityLabel("Microphone level")
                }
            } trailing: {
                if !micDenied {
                    Button(checks.playback.buttonTitle) { checks.hearYourself() }
                        .buttonStyle(MiniButtonStyle())
                        .disabled(checks.playback.phase != .idle)
                        .help("Records five seconds and plays them back, so you hear what others will. "
                            + "Nothing is saved.")
                }
            }
            if checks.inputs.isOn {
                MicComparison(mics: checks.comparableMics, active: monitor.snapshot.active(.microphone),
                              levels: checks.inputs.levels) { monitor.select($0) }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            if micDenied {
                HStack(spacing: 10) {
                    PanelNote(text: "Allow microphone access in System Settings › Privacy & Security")
                        .padding(.trailing, -14)
                    Button("Open Settings") { PrivacySettings.open(.microphone) }
                        .buttonStyle(MiniButtonStyle())
                        .padding(.trailing, 14)
                        .padding(.bottom, 8)
                }
            } else if let problem = micWarning {
                PanelNote(text: problem.message, caution: true)
            }
        }
    }

    /// A muted or zero-volume mic is already in the verdict, so only show the rest here.
    private var micWarning: MicProblem? {
        guard monitor.readyCheck.micProblem == nil else { return nil }
        return monitor.micProblem ?? (checks.meter.isSilent ? .silent : nil)
    }

    // MARK: Speaker

    private var speakerSection: some View {
        DeviceSection(kind: .speaker, monitor: monitor, selected: monitor.snapshot.active(.speaker)) {
            EmptyView()
        } detail: {
            EmptyView()
        } trailing: {
            Button(checks.tone.buttonTitle) { checks.tone.play() }
                .buttonStyle(MiniButtonStyle())
                .disabled(checks.tone.playing != nil)
        }
    }

    // MARK: Missing and flaky

    private var missingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Usually here, missing now")
            ForEach(monitor.missing) { missing in
                MissingRow(missing: missing)
            }
        }
    }

    private var flakySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Keeps disconnecting")
            ForEach(monitor.flaky, id: \.device.id) { flaky in
                FlakyRow(message: flaky.message, advice: flaky.advice)
            }
        }
    }
}

struct MissingRow: View {
    let missing: MissingDevice
    @Environment(\.panelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(missing.device.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.ink)
            HStack(spacing: 6) {
                Circle().fill(theme.caution).frame(width: 6, height: 6).accessibilityHidden(true)
                Text(summary).font(.system(size: 11.5)).foregroundStyle(theme.ink2)
            }
            Text(missing.reason.advice)
                .font(.system(size: 11.5))
                .foregroundStyle(theme.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        guard let lastSeen = missing.lastSeen else { return missing.reason.headline }
        return "\(missing.reason.headline) · last seen \(LastSeen.text(lastSeen))"
    }
}

struct FlakyRow: View {
    let message: String
    let advice: String
    @Environment(\.panelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(message)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(advice)
                .font(.system(size: 11.5))
                .foregroundStyle(theme.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }
}

enum LastSeen {
    static func text(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "today \(time)" }
        if calendar.isDateInYesterday(date) { return "yesterday \(time)" }
        return date.formatted(.dateTime.weekday(.wide).month().day())
    }
}
