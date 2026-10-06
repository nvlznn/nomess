import CoreText
import Foundation

/// How wide characters really are, in cells of a monospaced font. Terminals
/// draw CJK in exactly two cells, but outside a terminal a CJK glyph comes
/// from a fallback font and is narrower (punctuation much narrower).
public protocol GlyphMetrics {
    func cells(_ c: Character) -> Double
}

/// Measures with Core Text, including the fallback fonts it picks for
/// characters the font lacks, the same way rich-text apps lay them out.
public final class CoreTextMetrics: GlyphMetrics {
    private let font: CTFont
    private let cell: Double
    private var cache: [Character: Double] = [:]

    public init(font: CTFont) {
        self.font = font
        cell = Self.width("M", font)
    }

    /// Menlo, which the HTML asks for in apps that honour fonts.
    public static func menlo() -> CoreTextMetrics {
        CoreTextMetrics(font: CTFontCreateWithName("Menlo" as CFString, 12, nil))
    }

    public func cells(_ c: Character) -> Double {
        if let cached = cache[c] { return cached }
        let width = Self.width(String(c), font) / cell
        cache[c] = width
        return width
    }

    private static func width(_ s: String, _ font: CTFont) -> Double {
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attributes))
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }
}
