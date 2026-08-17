import Cocoa

class LinkOpenerService: NSObject, LinkOpenerProtocol {
    func open(_ url: URL, withReply reply: @escaping (Bool) -> Void) {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            reply(false)
            return
        }
        let result = NSWorkspace.shared.open(url)
        reply(result)
    }
}
