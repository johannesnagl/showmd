import Foundation

@objc public protocol LinkOpenerProtocol {
    func open(_ url: URL, withReply reply: @escaping (Bool) -> Void)
}
