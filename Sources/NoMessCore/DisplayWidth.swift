/// Terminal column width helpers. Wide (CJK / fullwidth / most emoji) scalars
/// take 2 columns, combining marks take 0, everything else takes 1.
enum DisplayWidth {
    static func of(_ s: Substring) -> Int {
        s.unicodeScalars.reduce(0) { $0 + of($1) }
    }

    static func of(_ s: String) -> Int {
        of(s[...])
    }

    static func of(_ c: Character) -> Int {
        c.unicodeScalars.reduce(0) { $0 + of($1) }
    }

    static func of(_ u: Unicode.Scalar) -> Int {
        let v = u.value
        if isZeroWidth(v) { return 0 }
        return isWide(v) ? 2 : 1
    }

    /// True for scripts that are written without spaces between words, so a
    /// line break between two of them must be joined without a space.
    static func isCJK(_ c: Character) -> Bool {
        guard let v = c.unicodeScalars.first?.value else { return false }
        switch v {
        case 0x1100...0x115F,   // Hangul Jamo
             0x2E80...0x303E,   // CJK radicals, punctuation
             0x3041...0x33FF,   // Kana, CJK symbols
             0x3400...0x4DBF,   // CJK Ext A
             0x4E00...0x9FFF,   // CJK Unified
             0xA960...0xA97F,
             0xAC00...0xD7A3,   // Hangul syllables
             0xF900...0xFAFF,   // CJK compatibility
             0xFE30...0xFE4F,   // CJK compatibility forms
             0xFF00...0xFF60,   // Fullwidth forms
             0xFFE0...0xFFE6,
             0x20000...0x3FFFD: // CJK Ext B+
            return true
        default:
            return false
        }
    }

    private static func isZeroWidth(_ v: UInt32) -> Bool {
        switch v {
        case 0x0300...0x036F, 0x200B...0x200F, 0xFE00...0xFE0F, 0x20D0...0x20FF:
            return true
        default:
            return false
        }
    }

    private static func isWide(_ v: UInt32) -> Bool {
        switch v {
        case 0x1100...0x115F,
             0x2E80...0x303E,
             0x3041...0x33FF,
             0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xA000...0xA4CF,
             0xAC00...0xD7A3,
             0xF900...0xFAFF,
             0xFE30...0xFE4F,
             0xFF00...0xFF60,
             0xFFE0...0xFFE6,
             0x1F300...0x1F64F,
             0x1F900...0x1F9FF,
             0x20000...0x3FFFD:
            return true
        default:
            return false
        }
    }
}
