import AVFoundation
import GreenRoomCore
import Observation

/// The live checks in the panel. They only run while the panel is open, so the camera
/// light and the mic indicator are never on in the background.
@MainActor
@Observable
final class Checks {
    let camera = CameraSession()
    let meter = MicMeter()
    let tone = TestTone()
    private(set) var cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)
    private(set) var micAccess = AVCaptureDevice.authorizationStatus(for: .audio)
    @ObservationIgnored private let monitor: DeviceMonitor
    @ObservationIgnored private var isRunning = false

    init(monitor: DeviceMonitor) {
        self.monitor = monitor
    }

    func start() {
        isRunning = true
        Task {
            if cameraAccess == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)
            }
            if micAccess == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
                micAccess = AVCaptureDevice.authorizationStatus(for: .audio)
            }
            guard isRunning else { return }
            restartCamera()
            restartMeter()
        }
    }

    func stop() {
        isRunning = false
        camera.stop()
        meter.stop()
    }

    func restartCamera() {
        guard isRunning, cameraAccess == .authorized,
              let device = monitor.previewCamera.flatMap(Cameras.captureDevice(for:)) else {
            camera.stop()
            return
        }
        camera.start(device)
    }

    func restartMeter() {
        guard isRunning, micAccess == .authorized else { return }
        meter.stop()
        meter.start()
    }
}
