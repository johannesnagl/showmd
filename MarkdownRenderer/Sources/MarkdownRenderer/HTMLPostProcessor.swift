import Foundation

enum HTMLPostProcessor {
    /// Applies all post-processing transformations to rendered HTML body.
    static func process(_ html: String) -> String {
        var result = html
        result = convertFootnotes(result)
        result = convertEmojiShortcodes(result)
        result = convertHighlight(result)
        result = convertSuperscript(result)
        result = convertSubscript(result)
        result = convertAutolinks(result)
        result = convertSmartQuotes(result)
        return result
    }

    // MARK: - Emoji shortcodes

    private static let emojiPattern = try! NSRegularExpression(
        pattern: ":([a-zA-Z0-9_+-]+):",
        options: []
    )

    static func convertEmojiShortcodes(_ html: String) -> String {
        let range = NSRange(html.startIndex..., in: html)
        let result = NSMutableString(string: html)
        let matches = emojiPattern.matches(in: html, range: range).reversed()
        for match in matches {
            guard let codeRange = Range(match.range(at: 1), in: html) else { continue }
            let code = String(html[codeRange])
            if insideHTMLTag(html: html, matchRange: match.range) { continue }
            if let emoji = emojiMap[code] {
                result.replaceCharacters(in: match.range, with: emoji)
            }
        }
        return result as String
    }

    // MARK: - ==highlight==

    private static let highlightPattern = try! NSRegularExpression(
        pattern: "==([^=]+)==",
        options: []
    )

    static func convertHighlight(_ html: String) -> String {
        let range = NSRange(html.startIndex..., in: html)
        return highlightPattern.stringByReplacingMatches(
            in: html, range: range,
            withTemplate: "<mark>$1</mark>"
        )
    }

    // MARK: - ^superscript^

    private static let superPattern = try! NSRegularExpression(
        pattern: "\\^([^^]+)\\^",
        options: []
    )

    static func convertSuperscript(_ html: String) -> String {
        let range = NSRange(html.startIndex..., in: html)
        return superPattern.stringByReplacingMatches(
            in: html, range: range,
            withTemplate: "<sup>$1</sup>"
        )
    }

    // MARK: - ~subscript~ (single tilde only, not ~~ strikethrough)

    private static let subPattern = try! NSRegularExpression(
        pattern: "(?<!~)~([^~]+)~(?!~)",
        options: []
    )

    static func convertSubscript(_ html: String) -> String {
        let range = NSRange(html.startIndex..., in: html)
        return subPattern.stringByReplacingMatches(
            in: html, range: range,
            withTemplate: "<sub>$1</sub>"
        )
    }

    // MARK: - Autolinks

    private static let autolinkPattern = try! NSRegularExpression(
        pattern: "(?<![\"=/>a-zA-Z])(https?://[^\\s<>\"')+\\]]+)",
        options: []
    )

    static func convertAutolinks(_ html: String) -> String {
        let range = NSRange(html.startIndex..., in: html)
        let result = NSMutableString(string: html)
        let matches = autolinkPattern.matches(in: html, range: range).reversed()
        for match in matches {
            if insideHTMLTag(html: html, matchRange: match.range) { continue }
            if insideAnchor(html: html, matchRange: match.range) { continue }
            guard let urlRange = Range(match.range(at: 1), in: html) else { continue }
            let url = String(html[urlRange])
            result.replaceCharacters(in: match.range, with: "<a href=\"\(url)\">\(url)</a>")
        }
        return result as String
    }

    // MARK: - Smart quotes

    static func convertSmartQuotes(_ html: String) -> String {
        var result = html
        // Double quotes: opening after whitespace/start, closing before whitespace/end/punctuation
        result = result.replacingOccurrences(
            of: "(^|[\\s(>])\"([^\"]*?)\"",
            with: "$1\u{201C}$2\u{201D}",
            options: .regularExpression
        )
        // Single quotes: apostrophes and opening/closing
        result = result.replacingOccurrences(
            of: "(?<=[a-zA-Z])'(?=[a-zA-Z])",
            with: "\u{2019}",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(^|[\\s(>])'([^']*?)'",
            with: "$1\u{2018}$2\u{2019}",
            options: .regularExpression
        )
        return result
    }

    // MARK: - Footnotes

    /// Converts `[^id]` references and `[^id]: content` definitions into HTML footnotes.
    static func convertFootnotes(_ html: String) -> String {
        // Extract definitions: <p>[^id]: content</p>
        let defPattern = try! NSRegularExpression(
            pattern: "<p>\\[\\^([^\\]]+)\\]:\\s*(.+?)</p>",
            options: .dotMatchesLineSeparators
        )
        let range = NSRange(html.startIndex..., in: html)
        var definitions: [(id: String, content: String)] = []
        let defMatches = defPattern.matches(in: html, range: range)
        for match in defMatches {
            guard let idRange = Range(match.range(at: 1), in: html),
                  let contentRange = Range(match.range(at: 2), in: html) else { continue }
            definitions.append((id: String(html[idRange]), content: String(html[contentRange])))
        }

        guard !definitions.isEmpty else { return html }

        // Remove definition paragraphs
        var result = defPattern.stringByReplacingMatches(in: html, range: range, withTemplate: "")

        // Replace references [^id] with superscript links
        for (index, def) in definitions.enumerated() {
            let num = index + 1
            let escapedId = NSRegularExpression.escapedPattern(for: def.id)
            let refPattern = try! NSRegularExpression(
                pattern: "\\[\\^\(escapedId)\\]",
                options: []
            )
            let refRange = NSRange(result.startIndex..., in: result)
            result = refPattern.stringByReplacingMatches(
                in: result, range: refRange,
                withTemplate: "<sup class=\"footnote-ref\"><a href=\"#fn-\(def.id)\" id=\"fnref-\(def.id)\">\(num)</a></sup>"
            )
        }

        // Append footnote section
        var section = "<hr class=\"footnotes-sep\">\n<section class=\"footnotes\">\n<ol>\n"
        for def in definitions {
            section += "<li id=\"fn-\(def.id)\"><p>\(def.content) <a href=\"#fnref-\(def.id)\" class=\"footnote-backref\">\u{21A9}</a></p></li>\n"
        }
        section += "</ol>\n</section>\n"
        result += section

        return result
    }

    // MARK: - Helpers

    private static func insideHTMLTag(html: String, matchRange: NSRange) -> Bool {
        guard let range = Range(matchRange, in: html) else { return false }
        let before = html[html.startIndex..<range.lowerBound]
        let lastOpen = before.lastIndex(of: "<")
        let lastClose = before.lastIndex(of: ">")
        if let open = lastOpen {
            if let close = lastClose {
                return open > close
            }
            return true
        }
        return false
    }

    private static func insideAnchor(html: String, matchRange: NSRange) -> Bool {
        guard let range = Range(matchRange, in: html) else { return false }
        let before = String(html[html.startIndex..<range.lowerBound])
        let openCount = before.components(separatedBy: "<a ").count - 1
        let closeCount = before.components(separatedBy: "</a>").count - 1
        return openCount > closeCount
    }

    // MARK: - Emoji map (common shortcodes)

    static let emojiMap: [String: String] = [
        "smile": "😄", "laughing": "😆", "blush": "😊", "smiley": "😃",
        "relaxed": "☺️", "smirk": "😏", "heart_eyes": "😍", "kissing_heart": "😘",
        "kissing_closed_eyes": "😚", "flushed": "😳", "relieved": "😌", "satisfied": "😆",
        "grin": "😁", "wink": "😉", "stuck_out_tongue_winking_eye": "😜",
        "stuck_out_tongue_closed_eyes": "😝", "grinning": "😀", "kissing": "😗",
        "kissing_smiling_eyes": "😙", "stuck_out_tongue": "😛", "sleeping": "😴",
        "worried": "😟", "frowning": "😦", "anguished": "😧", "open_mouth": "😮",
        "grimacing": "😬", "confused": "😕", "hushed": "😯", "expressionless": "😑",
        "unamused": "😒", "sweat_smile": "😅", "sweat": "😓",
        "disappointed_relieved": "😥", "weary": "😩", "pensive": "😔",
        "disappointed": "😞", "confounded": "😖", "fearful": "😨", "cold_sweat": "😰",
        "persevere": "😣", "cry": "😢", "sob": "😭", "joy": "😂",
        "astonished": "😲", "scream": "😱", "tired_face": "😫", "angry": "😠",
        "rage": "😡", "triumph": "😤", "sleepy": "😪", "yum": "😋",
        "mask": "😷", "sunglasses": "😎", "dizzy_face": "😵", "imp": "👿",
        "smiling_imp": "😈", "neutral_face": "😐", "no_mouth": "😶",
        "innocent": "😇", "alien": "👽",
        // Hand gestures
        "thumbsup": "👍", "+1": "👍", "thumbsdown": "👎", "-1": "👎",
        "ok_hand": "👌", "punch": "👊", "fist": "✊", "v": "✌️",
        "wave": "👋", "hand": "✋", "open_hands": "👐", "point_up": "☝️",
        "point_down": "👇", "point_left": "👈", "point_right": "👉",
        "raised_hands": "🙌", "pray": "🙏", "point_up_2": "👆", "clap": "👏",
        "muscle": "💪",
        // Hearts & symbols
        "heart": "❤️", "broken_heart": "💔", "two_hearts": "💕",
        "sparkling_heart": "💖", "heartpulse": "💗", "heartbeat": "💓",
        "revolving_hearts": "💞", "cupid": "💘", "blue_heart": "💙",
        "green_heart": "💚", "yellow_heart": "💛", "purple_heart": "💜",
        "gift_heart": "💝", "star": "⭐", "star2": "🌟", "sparkles": "✨",
        "sunny": "☀️", "cloud": "☁️", "zap": "⚡", "fire": "🔥",
        "boom": "💥", "snowflake": "❄️", "droplet": "💧",
        // Objects
        "rocket": "🚀", "tada": "🎉", "gift": "🎁", "bell": "🔔",
        "bookmark": "🔖", "bulb": "💡", "wrench": "🔧", "hammer": "🔨",
        "lock": "🔒", "unlock": "🔓", "key": "🔑", "mag": "🔍",
        "pencil": "📝", "pencil2": "✏️", "book": "📖", "books": "📚",
        "memo": "📝", "link": "🔗", "email": "📧", "phone": "📞",
        "computer": "💻", "bug": "🐛", "art": "🎨", "movie_camera": "🎥",
        "camera": "📷", "microphone": "🎤", "headphones": "🎧",
        // Flags & misc
        "checkered_flag": "🏁", "triangular_flag_on_post": "🚩",
        "warning": "⚠️", "x": "❌", "o": "⭕",
        "white_check_mark": "✅", "heavy_check_mark": "✔️",
        "heavy_multiplication_x": "✖️", "heavy_plus_sign": "➕",
        "heavy_minus_sign": "➖", "heavy_exclamation_mark": "❗",
        "question": "❓", "exclamation": "❗", "100": "💯",
        "recycle": "♻️", "white_large_square": "⬜", "black_large_square": "⬛",
        // Animals
        "dog": "🐶", "cat": "🐱", "mouse": "🐭", "hamster": "🐹",
        "rabbit": "🐰", "bear": "🐻", "panda_face": "🐼", "koala": "🐨",
        "tiger": "🐯", "lion": "🦁", "cow": "🐮", "pig": "🐷",
        "frog": "🐸", "monkey_face": "🐵", "chicken": "🐔", "penguin": "🐧",
        "bird": "🐦", "eagle": "🦅", "wolf": "🐺", "unicorn": "🦄",
        "bee": "🐝", "butterfly": "🦋", "snail": "🐌", "snake": "🐍",
        "turtle": "🐢", "octopus": "🐙", "fish": "🐟", "whale": "🐳",
        "dolphin": "🐬", "crab": "🦀",
        // Food
        "apple": "🍎", "green_apple": "🍏", "pizza": "🍕", "hamburger": "🍔",
        "fries": "🍟", "coffee": "☕", "beer": "🍺", "wine_glass": "🍷",
        "cake": "🎂", "cookie": "🍪", "ice_cream": "🍨", "taco": "🌮",
        // Nature
        "seedling": "🌱", "evergreen_tree": "🌲", "deciduous_tree": "🌳",
        "palm_tree": "🌴", "cactus": "🌵", "tulip": "🌷", "cherry_blossom": "🌸",
        "rose": "🌹", "sunflower": "🌻", "hibiscus": "🌺", "maple_leaf": "🍁",
        "fallen_leaf": "🍂", "leaves": "🍃", "mushroom": "🍄",
        "earth_americas": "🌎", "earth_africa": "🌍", "earth_asia": "🌏",
        "globe_with_meridians": "🌐", "ocean": "🌊", "rainbow": "🌈",
        // Arrows
        "arrow_up": "⬆️", "arrow_down": "⬇️", "arrow_left": "⬅️",
        "arrow_right": "➡️", "arrow_upper_right": "↗️",
        "arrow_lower_right": "↘️", "arrow_upper_left": "↖️",
        "arrow_lower_left": "↙️", "arrows_counterclockwise": "🔄",
    ]
}
