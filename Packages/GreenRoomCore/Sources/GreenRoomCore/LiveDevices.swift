import AVFoundation
import CoreAudio
import Foundation

/// Which apps have a microphone, speaker, or camera open right now.
public enum LiveDevices {
    /// Audio comes per app from Core Audio's process list (macOS 14.2 and later). Cameras only
    /// say whether some other app has them.
    public static func current(excluding ownPID: pid_t = ProcessInfo.processInfo.processIdentifier) -> [LiveUse] {
        var uses: [LiveUse] = []
        if #available(macOS 14.2, *) {
            uses += audioUses(excluding: ownPID)
        }
        for camera in Cameras.captureDevices() where camera.isInUseByAnotherApplication {
            uses.append(LiveUse(kind: .camera, deviceID: camera.uniqueID, app: nil))
        }
        return uses
    }

    @available(macOS 14.2, *)
    static func audioUses(excluding ownPID: pid_t) -> [LiveUse] {
        var uses = Set<LiveUse>()
        for process in AudioHardware.objectList(AudioHardware.system, kAudioHardwarePropertyProcessObjectList) {
            let pid = pid_t(bitPattern: AudioHardware.uint32(process, kAudioProcessPropertyPID))
            guard pid != ownPID, let path = executablePath(pid: pid), !isSystemService(path) else { continue }
            // Every process gets its own name, so two unnamed ones are never mixed up.
            let app = appName(executablePath: path) ?? "Process \(pid)"
            for (kind, scope, running) in [
                (DeviceKind.microphone, kAudioObjectPropertyScopeInput, kAudioProcessPropertyIsRunningInput),
                (DeviceKind.speaker, kAudioObjectPropertyScopeOutput, kAudioProcessPropertyIsRunningOutput)
            ] where AudioHardware.uint32(process, running) != 0 {
                for device in AudioHardware.objectList(process, kAudioProcessPropertyDevices, scope: scope)
                where AudioHardware.hasStreams(device, scope: scope) {
                    if let uid = AudioHardware.uid(device) {
                        uses.insert(LiveUse(kind: kind, deviceID: uid, app: app))
                    }
                }
            }
        }
        return uses.sorted { ($0.app ?? "", $0.deviceID) < ($1.app ?? "", $1.deviceID) }
    }

    static func executablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(bytes: bytes, encoding: .utf8)
    }

    /// macOS's own sound services (system alerts, Siri, dictation) play through the alert device
    /// and would read as an app using the wrong speaker.
    /// Apple's own apps like FaceTime live in /System/Applications and still count.
    static func isSystemService(_ path: String) -> Bool {
        path.hasPrefix("/System/Library/") || path.hasPrefix("/usr/") || path.hasPrefix("/Library/Apple/")
    }

    /// Helpers like "Google Chrome Helper" live inside their app's bundle, so the outermost
    /// `.app` in the executable's path names the app people recognize.

    static func appName(executablePath path: String) -> String? {
        let components = path.split(separator: "/")
        guard let bundle = components.first(where: { $0.hasSuffix(".app") }) else {
            return components.last.map(String.init)
        }
        return String(bundle.dropLast(4))
    }
}
