import Foundation

/// Centralised currency formatting so every surface uses the same symbol
/// and number style as the user's `UserSettings.defaultCurrency` choice.
///
/// Usage:
/// ```swift
/// let text = CurrencyFormatter.format(12345.0, currencyCode: "INR")
/// // → "₹12,345"
/// ```
enum CurrencyFormatter {

    // MARK: - Symbol lookup

    static var localeDefaultCurrencyCode: String {
        if let identifier = Locale.current.currency?.identifier, !identifier.isEmpty {
            return identifier
        }

        return "USD"
    }

    static var allCurrencyOptions: [CurrencyOption] {
        Locale.commonISOCurrencyCodes
            .map { code in
                CurrencyOption(
                    code: code,
                    symbol: symbol(for: code),
                    name: localizedName(for: code)
                )
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// Returns the display symbol for a given ISO 4217 currency code.
    /// Falls back to the code itself (e.g. "MXN") when not in the map.
    static func symbol(for currencyCode: String) -> String {
        let code = currencyCode.uppercased()
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = locale(forCurrencyCode: code) ?? Locale.current
        return formatter.currencySymbol ?? code
    }

    static func localizedName(for currencyCode: String) -> String {
        let code = currencyCode.uppercased()
        return Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    // MARK: - Formatting

    /// Formats `value` as an integer amount prefixed by the currency symbol.
    /// Example: `format(12345.0, currencyCode: "USD")` → `"$12,345"`
    static func format(_ value: Double, currencyCode: String) -> String {
        let sym = symbol(for: currencyCode)
        let formatted = numberString(value)
        return "\(sym)\(formatted)"
    }

    /// Formats `value` as a negative amount (expense display).
    /// Example: `formatNegative(500.0, currencyCode: "INR")` → `"-₹500"`
    static func formatNegative(_ value: Double, currencyCode: String) -> String {
        "-\(format(value, currencyCode: currencyCode))"
    }

    // MARK: - Internal helpers

    static func numberString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private static func locale(forCurrencyCode code: String) -> Locale? {
        Locale.availableIdentifiers
            .lazy
            .map(Locale.init(identifier:))
            .first { locale in
                locale.currency?.identifier == code
            }
    }
}

struct CurrencyOption: Identifiable, Equatable {
    let code: String
    let symbol: String
    let name: String

    var id: String { code }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        return code.localizedCaseInsensitiveContains(trimmed)
            || name.localizedCaseInsensitiveContains(trimmed)
            || symbol.localizedCaseInsensitiveContains(trimmed)
    }
}
