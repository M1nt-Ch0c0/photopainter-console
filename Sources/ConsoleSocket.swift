import Foundation
import Darwin

enum ConsoleSocket {
    enum Failure: Error { case unavailable, malformed }
    static func call(path: String, payload: Data) throws -> Data {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw Failure.unavailable }
        defer { Darwin.close(descriptor) }
        var timeout = timeval(tv_sec: 4, tv_usec: 0)
        var one: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one)))
        var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw Failure.unavailable }
        withUnsafeMutableBytes(of: &address.sun_path) { target in bytes.withUnsafeBytes { source in target.copyBytes(from: source) } }
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else { throw Failure.unavailable }
        var wire = payload; wire.append(0x0a)
        try wire.withUnsafeBytes { pointer in
            var sent = 0
            while sent < wire.count {
                let n = Darwin.send(descriptor, pointer.baseAddress!.advanced(by: sent), wire.count - sent, 0)
                guard n > 0 else { throw Failure.unavailable }; sent += n
            }
        }
        var result = Data(); var buffer = [UInt8](repeating: 0, count: 8192)
        while result.count < 512 * 1024 {
            let n = Darwin.recv(descriptor, &buffer, buffer.count, 0)
            guard n > 0 else { throw Failure.unavailable }
            result.append(contentsOf: buffer.prefix(n))
            if result.contains(0x0a) { return result }
        }
        throw Failure.malformed
    }
}
