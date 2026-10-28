import CoreGraphics
import Foundation
import IOKit
import Darwin

// Apple Silicon exposes DDC through undocumented IOKit functions. Resolve them
// at runtime so an OS change produces an error instead of a launch failure.
private typealias CreateService = @convention(c) (CFAllocator?) -> Unmanaged<CFTypeRef>?
private typealias Transfer = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> Int32

enum ProbeError: Error, CustomStringConvertible {
    case message(String)
    var description: String { if case let .message(value) = self { return value }; return "Unknown error" }
}

func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let target: UInt16?
    let delay: UInt32
    switch arguments {
    case ["read-input"]: target = nil; delay = 0
    case ["set-input", "hdmi1"]: target = 17; delay = 0
    case ["set-input", "displayport"]: target = 15; delay = 0
    case let args where args.count == 4 && args[0] == "set-input" &&
        ["hdmi1", "displayport"].contains(args[1]) && args[2] == "--delay":
        guard let parsed = UInt32(args[3]), (1...60).contains(parsed) else {
            throw ProbeError.message("Delay must be a whole number of seconds from 1 to 60.")
        }
        target = arguments[1] == "hdmi1" ? 17 : 15
        delay = parsed
    default: throw ProbeError.message("Usage: Helios read-input | set-input <hdmi1|displayport> [--delay <seconds>]")
    }
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
        throw ProbeError.message("No online displays found. Run from a logged-in macOS desktop session.")
    }
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetOnlineDisplayList(count, &displays, &count) == .success else {
        throw ProbeError.message("Could not enumerate displays.")
    }
    let external = displays.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 }
    guard external.count == 1, let display = external.first, CGDisplayIsMain(display) != 0 else {
        throw ProbeError.message("This prototype requires exactly one external display, set as the main display.")
    }
    guard let library = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
          let createSymbol = dlsym(library, "IOAVServiceCreate"),
          let writeSymbol = dlsym(library, "IOAVServiceWriteI2C"),
          let readSymbol = dlsym(library, "IOAVServiceReadI2C") else {
        throw ProbeError.message("The macOS DDC interface is unavailable.")
    }
    defer { dlclose(library) }
    let create = unsafeBitCast(createSymbol, to: CreateService.self)
    let write = unsafeBitCast(writeSymbol, to: Transfer.self)
    let read = unsafeBitCast(readSymbol, to: Transfer.self)
    guard let service = create(nil)?.takeRetainedValue() else {
        throw ProbeError.message("Could not open the display control service.")
    }
    let code: UInt8 = 0x60
    if let target {
        if delay > 0 {
            print("Switching input in \(delay) seconds. Press Control-C to cancel.")
            fflush(stdout)
            sleep(delay)
        }
        let high = UInt8(target >> 8)
        let low = UInt8(target & 0xff)
        var packet: [UInt8] = [0x84, 0x03, code, high, low]
        packet.append(packet.reduce(UInt8(0x6e ^ 0x51), ^))
        usleep(10_000)
        let result = packet.withUnsafeMutableBytes { write(service, 0x37, 0x51, $0.baseAddress!, UInt32($0.count)) }
        guard result == 0 else { throw ProbeError.message("DDC switch request failed (\(result)).") }
        print("Input switch request sent: \(target). Confirm the monitor changed sources.")
        return
    }
    var request: [UInt8] = [0x82, 0x01, code, 0x6e ^ 0x82 ^ 0x01 ^ code]
    usleep(10_000)
    let writeResult = request.withUnsafeMutableBytes { write(service, 0x37, 0x51, $0.baseAddress!, UInt32($0.count)) }
    guard writeResult == 0 else { throw ProbeError.message("DDC request failed (\(writeResult)).") }
    usleep(50_000)
    var reply = [UInt8](repeating: 0, count: 12)
    let readResult = reply.withUnsafeMutableBytes { read(service, 0x37, 0x51, $0.baseAddress!, UInt32($0.count)) }
    guard readResult == 0 else { throw ProbeError.message("DDC response failed (\(readResult)).") }
    guard reply[0] == 0x6e, reply[1] == 0x88, reply[2] == 0x02,
          reply[3] == 0, reply[4] == code,
          reply.prefix(11).reduce(UInt8(0x50), ^) == 0 else {
        throw ProbeError.message("The monitor returned an invalid or unsupported DDC response.")
    }
    let value = UInt16(reply[8]) << 8 | UInt16(reply[9])
    print("Display vendor \(CGDisplayVendorNumber(display)), model \(CGDisplayModelNumber(display)): input \(value) (0x\(String(value, radix: 16)))")
}

if CommandLine.arguments.dropFirst().elementsEqual(["window"]) {
    startWindow()
} else {
    do { try run() } catch {
        fputs("Helios: \(error)\n", stderr)
        exit(1)
    }
}
