import Cocoa
import ApplicationServices

struct OffScreenResult {
    let appName: String
    let totalOffScreenMatches: Int
    let matchesAbove: Int
    let matchesBelow: Int
}

final class AccessibilityService {

    /// Gets off-screen text matches for the given query in the frontmost app.
    /// Best-effort: returns nil if AX is unavailable or times out.
    func getOffScreenMatches(query: String) async -> OffScreenResult? {
        guard AXIsProcessTrusted() else { return nil }
        guard !query.isEmpty else { return nil }

        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appName = app.localizedName ?? "Unknown"
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        // Find text elements in the AX tree
        var allText: [(text: String, visibleRange: Range<Int>?, fullLength: Int)] = []
        collectTextElements(from: axApp, depth: 0, maxDepth: 10, results: &allText)

        // Count matches above/below visible area
        var above = 0, below = 0
        for element in allText {
            let matches = countOccurrences(of: query, in: element.text)
            if matches == 0 { continue }

            if let visibleRange = element.visibleRange {
                // Count matches in non-visible portions
                // Text before visible range
                if visibleRange.lowerBound > 0 {
                    let prefix = String(element.text.prefix(visibleRange.lowerBound))
                    above += countOccurrences(of: query, in: prefix)
                }
                // Text after visible range
                if visibleRange.upperBound < element.fullLength {
                    let suffix = String(element.text.suffix(element.fullLength - visibleRange.upperBound))
                    below += countOccurrences(of: query, in: suffix)
                }
            }
        }

        let total = above + below
        if total == 0 { return nil }

        return OffScreenResult(
            appName: appName,
            totalOffScreenMatches: total,
            matchesAbove: above,
            matchesBelow: below
        )
    }

    private func collectTextElements(from element: AXUIElement, depth: Int, maxDepth: Int, results: inout [(text: String, visibleRange: Range<Int>?, fullLength: Int)]) {
        guard depth < maxDepth else { return }

        // Try to get role
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String else { return }

        // Check text-bearing roles
        let textRoles = [kAXTextAreaRole, kAXTextFieldRole, kAXStaticTextRole]
        if textRoles.contains(role) {
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
               let text = valueRef as? String, !text.isEmpty {

                // Try to get visible character range
                var visibleRangeRef: CFTypeRef?
                var visibleRange: Range<Int>? = nil
                if AXUIElementCopyAttributeValue(element, "AXVisibleCharacterRange" as CFString, &visibleRangeRef) == .success,
                   let rangeValue = visibleRangeRef {
                    var cfRange = CFRange(location: 0, length: 0)
                    if AXValueGetValue(rangeValue as! AXValue, .cfRange, &cfRange) {
                        visibleRange = cfRange.location..<(cfRange.location + cfRange.length)
                    }
                }

                results.append((text: text, visibleRange: visibleRange, fullLength: text.count))
            }
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectTextElements(from: child, depth: depth + 1, maxDepth: maxDepth, results: &results)
            }
        }
    }

    private func countOccurrences(of query: String, in text: String) -> Int {
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<text.endIndex
        }
        return count
    }
}
