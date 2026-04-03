import Foundation

enum HTMLPostProcessor {
    /// Applies all post-processing transformations to rendered HTML body.
    static func process(_ html: String) -> String {
        var result = html
        result = convertFootnotes(result)
        result = transformTextSegments(result) { text in
            var t = text
            t = applyEmojiShortcodes(t)
            t = applyHighlight(t)
            t = applySuperscript(t)
            t = applySubscript(t)
            t = applyAutolinks(t)
            t = applySmartQuotes(t)
            return t
        }
        return result
    }

    // MARK: - Text segment extraction

    /// Splits HTML into protected regions (tags, <pre>…</pre>, <code>…</code>)
    /// and text regions. Only text regions are passed to the transform closure.
    static func transformTextSegments(_ html: String, transform: (String) -> String) -> String {
        // Match HTML tags and <pre>…</pre> / <code>…</code> blocks
        let protectedPattern = try! NSRegularExpression(
            pattern: "<pre[^>]*>[\\s\\S]*?</pre>|<code[^>]*>[\\s\\S]*?</code>|<a [^>]*>[\\s\\S]*?</a>|<[^>]+>",
            options: .caseInsensitive
        )
        let range = NSRange(html.startIndex..., in: html)
        let matches = protectedPattern.matches(in: html, range: range)

        var result = ""
        var lastEnd = html.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: html) else { continue }
            // Transform the text segment before this match
            if lastEnd < matchRange.lowerBound {
                let textSegment = String(html[lastEnd..<matchRange.lowerBound])
                result += transform(textSegment)
            }
            // Append the protected region unchanged
            result += html[matchRange]
            lastEnd = matchRange.upperBound
        }

        // Transform any remaining text after the last match
        if lastEnd < html.endIndex {
            let textSegment = String(html[lastEnd...])
            result += transform(textSegment)
        }

        return result
    }

    // MARK: - Emoji shortcodes (operates on text segments only)

    private static let emojiPattern = try! NSRegularExpression(
        pattern: ":([a-zA-Z0-9_+-]+):",
        options: []
    )

    static func applyEmojiShortcodes(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let result = NSMutableString(string: text)
        let matches = emojiPattern.matches(in: text, range: range).reversed()
        for match in matches {
            guard let codeRange = Range(match.range(at: 1), in: text) else { continue }
            let code = String(text[codeRange])
            if let emoji = emojiMap[code] {
                result.replaceCharacters(in: match.range, with: emoji)
            }
        }
        return result as String
    }

    // Keep public wrappers for backward-compatible test access
    static func convertEmojiShortcodes(_ html: String) -> String {
        transformTextSegments(html) { applyEmojiShortcodes($0) }
    }

    // MARK: - ==highlight==

    private static let highlightPattern = try! NSRegularExpression(
        pattern: "==([^=]+)==",
        options: []
    )

    static func applyHighlight(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return highlightPattern.stringByReplacingMatches(
            in: text, range: range,
            withTemplate: "<mark>$1</mark>"
        )
    }

    static func convertHighlight(_ html: String) -> String {
        transformTextSegments(html) { applyHighlight($0) }
    }

    // MARK: - ^superscript^

    private static let superPattern = try! NSRegularExpression(
        pattern: "\\^([^^]+)\\^",
        options: []
    )

    static func applySuperscript(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return superPattern.stringByReplacingMatches(
            in: text, range: range,
            withTemplate: "<sup>$1</sup>"
        )
    }

    static func convertSuperscript(_ html: String) -> String {
        transformTextSegments(html) { applySuperscript($0) }
    }

    // MARK: - ~subscript~ (single tilde only, not ~~ strikethrough)

    private static let subPattern = try! NSRegularExpression(
        pattern: "(?<!~)~([^~]+)~(?!~)",
        options: []
    )

    static func applySubscript(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return subPattern.stringByReplacingMatches(
            in: text, range: range,
            withTemplate: "<sub>$1</sub>"
        )
    }

    static func convertSubscript(_ html: String) -> String {
        transformTextSegments(html) { applySubscript($0) }
    }

    // MARK: - Autolinks

    private static let autolinkPattern = try! NSRegularExpression(
        pattern: "(https?://[^\\s<>\"')+\\]]+)",
        options: []
    )

    static func applyAutolinks(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let result = NSMutableString(string: text)
        let matches = autolinkPattern.matches(in: text, range: range).reversed()
        for match in matches {
            guard let urlRange = Range(match.range(at: 1), in: text) else { continue }
            // Text segments are already HTML-escaped by the visitor, so don't re-escape
            let url = String(text[urlRange])
            result.replaceCharacters(in: match.range, with: "<a href=\"\(url)\">\(url)</a>")
        }
        return result as String
    }

    static func convertAutolinks(_ html: String) -> String {
        transformTextSegments(html) { applyAutolinks($0) }
    }

    // MARK: - Smart quotes (operates on text segments only — no HTML attributes)

    static func applySmartQuotes(_ text: String) -> String {
        var result = text
        // Double quotes
        result = result.replacingOccurrences(
            of: "\"([^\"]*?)\"",
            with: "\u{201C}$1\u{201D}",
            options: .regularExpression
        )
        // Apostrophes
        result = result.replacingOccurrences(
            of: "(?<=[a-zA-Z])'(?=[a-zA-Z])",
            with: "\u{2019}",
            options: .regularExpression
        )
        // Single quotes
        result = result.replacingOccurrences(
            of: "'([^']*?)'",
            with: "\u{2018}$1\u{2019}",
            options: .regularExpression
        )
        return result
    }

    static func convertSmartQuotes(_ html: String) -> String {
        transformTextSegments(html) { applySmartQuotes($0) }
    }

    // MARK: - Footnotes

    /// Converts `[^id]` references and `[^id]: content` definitions into HTML footnotes.
    static func convertFootnotes(_ html: String) -> String {
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

        var result = defPattern.stringByReplacingMatches(in: html, range: range, withTemplate: "")

        for (index, def) in definitions.enumerated() {
            let num = index + 1
            let safeId = HTMLEscape.escape(def.id)
            let escapedId = NSRegularExpression.escapedPattern(for: def.id)
            let refPattern = try! NSRegularExpression(
                pattern: "\\[\\^\(escapedId)\\]",
                options: []
            )
            let refRange = NSRange(result.startIndex..., in: result)
            result = refPattern.stringByReplacingMatches(
                in: result, range: refRange,
                withTemplate: "<sup class=\"footnote-ref\"><a href=\"#fn-\(safeId)\" id=\"fnref-\(safeId)\">\(num)</a></sup>"
            )
        }

        var section = "<hr class=\"footnotes-sep\">\n<section class=\"footnotes\">\n<ol>\n"
        for def in definitions {
            let safeId = HTMLEscape.escape(def.id)
            section += "<li id=\"fn-\(safeId)\"><p>\(def.content) <a href=\"#fnref-\(safeId)\" class=\"footnote-backref\">\u{21A9}</a></p></li>\n"
        }
        section += "</ol>\n</section>\n"
        result += section

        return result
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
        "thumbsup": "👍", "+1": "👍", "thumbsdown": "👎", "-1": "👎",
        "ok_hand": "👌", "punch": "👊", "fist": "✊", "v": "✌️",
        "wave": "👋", "hand": "✋", "open_hands": "👐", "point_up": "☝️",
        "point_down": "👇", "point_left": "👈", "point_right": "👉",
        "raised_hands": "🙌", "pray": "🙏", "point_up_2": "👆", "clap": "👏",
        "muscle": "💪",
        "heart": "❤️", "broken_heart": "💔", "two_hearts": "💕",
        "sparkling_heart": "💖", "heartpulse": "💗", "heartbeat": "💓",
        "revolving_hearts": "💞", "cupid": "💘", "blue_heart": "💙",
        "green_heart": "💚", "yellow_heart": "💛", "purple_heart": "💜",
        "gift_heart": "💝", "star": "⭐", "star2": "🌟", "sparkles": "✨",
        "sunny": "☀️", "cloud": "☁️", "zap": "⚡", "fire": "🔥",
        "boom": "💥", "snowflake": "❄️", "droplet": "💧",
        "rocket": "🚀", "tada": "🎉", "gift": "🎁", "bell": "🔔",
        "bookmark": "🔖", "bulb": "💡", "wrench": "🔧", "hammer": "🔨",
        "lock": "🔒", "unlock": "🔓", "key": "🔑", "mag": "🔍",
        "pencil": "📝", "pencil2": "✏️", "book": "📖", "books": "📚",
        "memo": "📝", "link": "🔗", "email": "📧", "phone": "📞",
        "computer": "💻", "bug": "🐛", "art": "🎨", "movie_camera": "🎥",
        "camera": "📷", "microphone": "🎤", "headphones": "🎧",
        "checkered_flag": "🏁", "triangular_flag_on_post": "🚩",
        "warning": "⚠️", "x": "❌", "o": "⭕",
        "white_check_mark": "✅", "heavy_check_mark": "✔️",
        "heavy_multiplication_x": "✖️", "heavy_plus_sign": "➕",
        "heavy_minus_sign": "➖", "heavy_exclamation_mark": "❗",
        "question": "❓", "exclamation": "❗", "100": "💯",
        "recycle": "♻️", "white_large_square": "⬜", "black_large_square": "⬛",
        "dog": "🐶", "cat": "🐱", "mouse": "🐭", "hamster": "🐹",
        "rabbit": "🐰", "bear": "🐻", "panda_face": "🐼", "koala": "🐨",
        "tiger": "🐯", "lion": "🦁", "cow": "🐮", "pig": "🐷",
        "frog": "🐸", "monkey_face": "🐵", "chicken": "🐔", "penguin": "🐧",
        "bird": "🐦", "eagle": "🦅", "wolf": "🐺", "unicorn": "🦄",
        "bee": "🐝", "butterfly": "🦋", "snail": "🐌", "snake": "🐍",
        "turtle": "🐢", "octopus": "🐙", "fish": "🐟", "whale": "🐳",
        "dolphin": "🐬", "crab": "🦀",
        "apple": "🍎", "green_apple": "🍏", "pizza": "🍕", "hamburger": "🍔",
        "fries": "🍟", "coffee": "☕", "beer": "🍺", "wine_glass": "🍷",
        "cake": "🎂", "cookie": "🍪", "ice_cream": "🍨", "taco": "🌮",
        "seedling": "🌱", "evergreen_tree": "🌲", "deciduous_tree": "🌳",
        "palm_tree": "🌴", "cactus": "🌵", "tulip": "🌷", "cherry_blossom": "🌸",
        "rose": "🌹", "sunflower": "🌻", "hibiscus": "🌺", "maple_leaf": "🍁",
        "fallen_leaf": "🍂", "leaves": "🍃", "mushroom": "🍄",
        "earth_americas": "🌎", "earth_africa": "🌍", "earth_asia": "🌏",
        "globe_with_meridians": "🌐", "ocean": "🌊", "rainbow": "🌈",
        "arrow_up": "⬆️", "arrow_down": "⬇️", "arrow_left": "⬅️",
        "arrow_right": "➡️", "arrow_upper_right": "↗️",
        "arrow_lower_right": "↘️", "arrow_upper_left": "↖️",
        "arrow_lower_left": "↙️", "arrows_counterclockwise": "🔄",
        "eyes": "👀", "thinking": "🤔", "metal": "🤘",
    ]
}
