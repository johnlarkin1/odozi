#if os(macOS)
    import AppKit

    public typealias PlatformColor = NSColor
#elseif os(watchOS)
    import UIKit

    public typealias PlatformColor = UIColor
#else
    import UIKit

    public typealias PlatformColor = UIColor
#endif
