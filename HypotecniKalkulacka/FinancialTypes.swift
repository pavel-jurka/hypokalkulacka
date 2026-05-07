/// FinancialTypes.swift — HypotecniKalkulacka
///
/// Sémantické typové aliasy pro finanční výpočty.
/// Zajišťují čitelnost kódu bez narušení SwiftUI binding kompatibility.

import Foundation

// MARK: - Financial Type Aliases

/// Částka v českých korunách.
typealias CZK = Double

/// Procentuální hodnota (např. 4.79 = 4.79 %).
typealias Percent = Double

/// Počet let (např. délka hypotéky).
typealias Years = Double

/// Počet měsíců (např. neobsazenost).
typealias Months = Double

// MARK: - Formatting

/// Formátuje částku v Kč. compact = zkrácený formát pro grafy (1,2 M / 350 k).
func czk(_ value: CZK, compact: Bool = false) -> String {
    if compact {
        let a = Swift.abs(value)
        let sign = value < 0 ? "−" : ""
        if a >= 1_000_000 { return "\(sign)\(String(format: "%.1f", a / 1_000_000)) M" }
        if a >= 1_000     { return "\(sign)\(String(format: "%.0f", a / 1_000)) k" }
        return "\(sign)\(String(format: "%.0f", a))"
    }
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.groupingSeparator = "\u{202F}"
    return (f.string(from: NSNumber(value: value)) ?? "\(Int(value))") + " Kč"
}
