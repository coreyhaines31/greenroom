import CoreMediaIO
import Foundation

/// AVFoundation's exclusive-use flag can stay false for shared cameras. CoreMediaIO reports IO
/// across processes, but cannot name the app; callers must exclude their own preview's device.
public enum CameraActivity {
    public static func runningDeviceIDs() -> Set<String> {
        var address = address(kCMIOHardwarePropertyDevices)
        var size: UInt32 = 0
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &size, &devices) == noErr else { return [] }
        return Set(devices.compactMap { device in
            var address = Self.address(kCMIODevicePropertyDeviceIsRunningSomewhere)
            var running: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            guard CMIOObjectGetPropertyData(device, &address, 0, nil, size, &size, &running) == noErr,
                  running != 0 else { return nil }
            address = Self.address(kCMIODevicePropertyDeviceUID)
            var value: Unmanaged<CFString>?
            size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let status = withUnsafeMutablePointer(to: &value) {
                CMIOObjectGetPropertyData(device, &address, 0, nil, size, &size, $0)
            }
            guard status == noErr, let value else { return nil }
            return value.takeRetainedValue() as String
        })
    }

    private static func address(_ selector: Int) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(selector),
                                  mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                  mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    }
}
