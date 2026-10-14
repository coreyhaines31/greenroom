import Foundation
import IOKit

/// Product names of everything on the USB bus right now, hubs included. Lets us tell
/// "not plugged in" apart from "plugged in, but not working as a camera or mic".
public enum USBDevices {
    public static func productNames() -> [String] {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator)
                == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var names: [String] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            for key in ["USB Product Name", "kUSBProductString"] {
                if let name = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? String {
                    names.append(name)
                    break
                }
            }
        }
        return names
    }

    /// Audio and camera names often add words to the USB product name ("ATR2100x-USB
    /// Microphone" vs "ATR2100x-USB"), so match on either containing the other, or on a
    /// distinctive first word.
    public static func matches(_ deviceName: String, in productNames: [String]) -> Bool {
        let target = normalized(deviceName)
        guard !target.isEmpty else { return false }
        let firstWord = deviceName.split(separator: " ").first.map { normalized(String($0)) } ?? ""
        return productNames.map(normalized).contains { product in
            guard !product.isEmpty else { return false }
            return product.contains(target) || target.contains(product)
                || (firstWord.count >= 5 && product.contains(firstWord))
        }
    }

    static func normalized(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
