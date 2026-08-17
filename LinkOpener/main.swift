import Foundation

let delegate = LinkOpenerDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
