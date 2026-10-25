import Foundation

enum WordCount {
    /// Counts words as the system's text segmentation sees them, so Chinese text without
    /// spaces counts too.
    static func of(_ text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) {
            _, _, _, _ in count += 1
        }
        return count
    }
}
