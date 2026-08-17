import Foundation

class LinkOpenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: LinkOpenerProtocol.self)
        newConnection.exportedObject = LinkOpenerService()
        newConnection.resume()
        return true
    }
}
