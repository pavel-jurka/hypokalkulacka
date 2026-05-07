/// MortgageViewModel.swift — HypotecniKalkulacka
///
/// @Observable ViewModel — drží UI stav a deleguje výpočty na CalculationEngine.
/// Propojuje domain logiku se SwiftUI views.

import SwiftUI
import Observation

@Observable
class MortgageViewModel {

    // MARK: Vstupy — Nemovitost
    var propertyPrice: CZK = 9_900_000
    var ownCapitalPct: Percent = 10
    var includeReconstruction: Bool = false
    var reconstructionAmount: CZK = 1_000_000
    var includeAppreciation: Bool = false
    var propertyAppreciationPct: Percent = 3.0

    // MARK: Vstupy — Hypotéka
    var mortgageYears: Years = 30
    var interestRate: Percent = 4.79

    // MARK: Vstupy — Refixace
    var useRefixation: Bool = false
    var refixYear: Years = 5
    var refixRate: Percent = 5.0

    // MARK: Vstupy — Příjmy z nájmu
    var monthlyRent: CZK = 25_000
    var rentGrowthPct: Percent = 2.0
    var vacancyMonths: Months = 1

    // MARK: Vstupy — Provozní náklady
    var includeManagement: Bool = false
    var managementFeePct: Percent = 10
    var annualInsurance: CZK = 8_000
    var monthlySVJ: CZK = 3_000

    // MARK: Vstupy — Opravy a údržba
    var annualRepairs: CZK = 130_000
    var largeRepairAmount: CZK = 300_000
    var largeRepairEveryNYears: Years = 10

    // MARK: Vstupy — Alternativní investice
    var includeOpportunityCost: Bool = false
    var alternativeReturnPct: Percent = 7.0

    // MARK: Vstupy — Inflace
    var includeInflation: Bool = false
    var inflationRate: Percent = 2.5

    // MARK: Vstupy — Daň z příjmu z nájmu
    var includeTax: Bool = true
    var taxMode: TaxMode = .pausalni
    var taxRate: Percent = 15

    // MARK: Vstupy — Časová osa
    var selectedYear: Years = 10

    // MARK: Vstupy — Mimořádné splátky
    var extraPayments: [ExtraPayment] = []
    var newExtraYear: Int = 1
    var newExtraAmount: CZK = 1_000_000
    var useRentAsExtraPayments: Bool = false

    func addExtraPayment() {
        extraPayments.append(ExtraPayment(year: newExtraYear, amount: newExtraAmount))
        extraPayments.sort { $0.year < $1.year }
    }
    func removeExtraPayment(id: UUID) {
        extraPayments.removeAll { $0.id == id }
    }

    // MARK: - Inputs snapshot

    /// Vytvoří snapshot vstupů pro CalculationEngine.
    private var inputs: MortgageInputs {
        MortgageInputs(
            propertyPrice: propertyPrice,
            ownCapitalPct: ownCapitalPct,
            includeReconstruction: includeReconstruction,
            reconstructionAmount: reconstructionAmount,
            includeAppreciation: includeAppreciation,
            propertyAppreciationPct: propertyAppreciationPct,
            mortgageYears: mortgageYears,
            interestRate: interestRate,
            useRefixation: useRefixation,
            refixYear: refixYear,
            refixRate: refixRate,
            monthlyRent: monthlyRent,
            rentGrowthPct: rentGrowthPct,
            vacancyMonths: vacancyMonths,
            includeManagement: includeManagement,
            managementFeePct: managementFeePct,
            annualInsurance: annualInsurance,
            monthlySVJ: monthlySVJ,
            annualRepairs: annualRepairs,
            largeRepairAmount: largeRepairAmount,
            largeRepairEveryNYears: largeRepairEveryNYears,
            includeTax: includeTax,
            taxMode: taxMode,
            taxRate: taxRate,
            extraPayments: extraPayments,
            useRentAsExtraPayments: useRentAsExtraPayments,
            includeOpportunityCost: includeOpportunityCost,
            alternativeReturnPct: alternativeReturnPct,
            includeInflation: includeInflation,
            inflationRate: inflationRate
        )
    }

    // MARK: - Odvozené (delegují na CalculationEngine)

    var totalPropertyCost: CZK { inputs.totalPropertyCost }
    var mortgageAmount: CZK    { inputs.mortgageAmount }
    var downPayment: CZK       { inputs.downPayment }

    var monthlyPayment: CZK {
        CalculationEngine.monthlyPayment(principal: mortgageAmount,
                                         annualRate: interestRate,
                                         years: mortgageYears)
    }

    var monthlyPaymentAfterRefix: CZK {
        CalculationEngine.monthlyPaymentAfterRefix(inputs)
    }

    var autoExtraPayments: [ExtraPayment] {
        CalculationEngine.autoExtraPayments(inputs)
    }

    var allExtraPayments: [ExtraPayment] {
        (extraPayments + autoExtraPayments).sorted { $0.year < $1.year }
    }

    var schedule: [YearData] {
        CalculationEngine.computeSchedule(inputs, allExtraPayments: allExtraPayments)
    }

    // MARK: Snapshot ke zvolenému roku

    var snapYear: Int { max(1, min(Int(selectedYear), Int(mortgageYears))) }
    private var upTo: [YearData] { schedule.filter { $0.year <= snapYear } }

    var snapCumPayments: CZK   { upTo.reduce(0) { $0 + $1.annualPayment + $1.extraPayment } }
    var snapCumInterest: CZK   { upTo.reduce(0) { $0 + $1.interestPaid } }
    var snapCumPrincipal: CZK  { upTo.reduce(0) { $0 + $1.principalPaid } }
    var snapRemainingDebt: CZK { upTo.last?.remainingBalance ?? mortgageAmount }
    var snapCumRent: CZK       { upTo.reduce(0) { $0 + $1.rentalIncome } }
    var snapCumRepairs: CZK    { upTo.reduce(0) { $0 + $1.repairCost } }
    var snapCumTax: CZK        { upTo.reduce(0) { $0 + $1.taxAmount } }
    var snapCumOperating: CZK  { upTo.reduce(0) { $0 + $1.operatingCosts } }
    var snapNet: CZK           { upTo.last?.cumulativeNet ?? -downPayment }
    var snapCashflow: CZK      { snapCumRent - snapCumPayments - snapCumTax - snapCumOperating }
    var snapPropertyValue: CZK { upTo.last?.propertyValue ?? propertyPrice }
    var snapTotalInvestment: CZK { snapNet + snapPropertyValue - snapRemainingDebt }

    var snapOpportunityCost: CZK {
        downPayment * pow(1 + alternativeReturnPct / 100, Double(snapYear)) - downPayment
    }
    var snapNetReal: CZK {
        snapNet / pow(1 + inflationRate / 100, Double(snapYear))
    }

    var payoffYear: Int? {
        schedule.first(where: { $0.remainingBalance == 0 && $0.annualPayment > 0 })?.year
    }

    // MARK: Celkové výsledky

    var totalInterest: CZK    { schedule.reduce(0) { $0 + $1.interestPaid } }
    var totalRent: CZK        { schedule.reduce(0) { $0 + $1.rentalIncome } }
    var totalRepairs: CZK     { schedule.reduce(0) { $0 + $1.repairCost } }
    var totalTax: CZK         { schedule.reduce(0) { $0 + $1.taxAmount } }
    var totalOperating: CZK   { schedule.reduce(0) { $0 + $1.operatingCosts } }
    var finalBalance: CZK     { schedule.last?.cumulativeNet ?? 0 }
    var finalPropertyValue: CZK { schedule.last?.propertyValue ?? propertyPrice }
    var finalTotalInvestment: CZK { finalBalance + finalPropertyValue - (schedule.last?.remainingBalance ?? 0) }
    var breakEvenYear: Int?   { schedule.first(where: { $0.cumulativeNet >= 0 })?.year }

    // MARK: PDF export

    @MainActor
    func generatePDF() -> URL? {
        let reportView = PDFReportView(vm: self).frame(width: 1000)
        let renderer = ImageRenderer(content: reportView)
        renderer.scale = 2.0

        guard let cgImage = renderer.cgImage else { return nil }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let url = URL.temporaryDirectory
            .appendingPathComponent("HypotecniKalkulacka_\(Int(Date().timeIntervalSince1970)).pdf")

        var mediaBox = CGRect(origin: .zero, size: imageSize)
        guard let pdf = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return nil }
        pdf.beginPDFPage(nil)
        pdf.draw(cgImage, in: mediaBox)
        pdf.endPDFPage()
        pdf.closePDF()

        return url
    }
}
