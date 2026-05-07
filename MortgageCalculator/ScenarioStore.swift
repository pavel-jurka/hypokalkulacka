/// ScenarioStore.swift — Ukládání a načítání scénářů

import Foundation

/// Uložený pojmenovaný scénář — snapshot všech vstupních parametrů.
struct MortgageScenario: Codable, Identifiable, Hashable {
    static func == (lhs: MortgageScenario, rhs: MortgageScenario) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var id = UUID()
    var name: String
    var createdAt: Date = Date()

    // Nemovitost
    var propertyPrice: CZK
    var ownCapitalPct: Percent
    var includeReconstruction: Bool
    var reconstructionAmount: CZK
    var includeAppreciation: Bool
    var propertyAppreciationPct: Percent

    // Hypotéka
    var mortgageYears: Years
    var interestRate: Percent
    var useRefixation: Bool
    var refixYear: Years
    var refixRate: Percent

    // Příjmy
    var monthlyRent: CZK
    var rentGrowthPct: Percent
    var vacancyMonths: Months

    // Provoz
    var includeManagement: Bool
    var managementFeePct: Percent
    var annualInsurance: CZK
    var monthlySVJ: CZK

    // Opravy
    var annualRepairs: CZK
    var largeRepairAmount: CZK
    var largeRepairEveryNYears: Years

    // Daň
    var includeTax: Bool
    var taxMode: TaxMode
    var taxRate: Percent

    // Srovnání
    var includeOpportunityCost: Bool
    var alternativeReturnPct: Percent
    var includeInflation: Bool
    var inflationRate: Percent

    // Extra splátky
    var useRentAsExtraPayments: Bool

    /// Klíčové výsledky (vypočtené při uložení).
    var finalBalance: CZK
    var breakEvenYear: Int?
    var monthlyPayment: CZK
    var totalInterest: CZK
}

extension MortgageScenario {
    /// Vytvoří scénář z aktuálního stavu ViewModelu.
    init(name: String, vm: MortgageViewModel) {
        self.name = name
        self.propertyPrice = vm.propertyPrice
        self.ownCapitalPct = vm.ownCapitalPct
        self.includeReconstruction = vm.includeReconstruction
        self.reconstructionAmount = vm.reconstructionAmount
        self.includeAppreciation = vm.includeAppreciation
        self.propertyAppreciationPct = vm.propertyAppreciationPct
        self.mortgageYears = vm.mortgageYears
        self.interestRate = vm.interestRate
        self.useRefixation = vm.useRefixation
        self.refixYear = vm.refixYear
        self.refixRate = vm.refixRate
        self.monthlyRent = vm.monthlyRent
        self.rentGrowthPct = vm.rentGrowthPct
        self.vacancyMonths = vm.vacancyMonths
        self.includeManagement = vm.includeManagement
        self.managementFeePct = vm.managementFeePct
        self.annualInsurance = vm.annualInsurance
        self.monthlySVJ = vm.monthlySVJ
        self.annualRepairs = vm.annualRepairs
        self.largeRepairAmount = vm.largeRepairAmount
        self.largeRepairEveryNYears = vm.largeRepairEveryNYears
        self.includeTax = vm.includeTax
        self.taxMode = vm.taxMode
        self.taxRate = vm.taxRate
        self.includeOpportunityCost = vm.includeOpportunityCost
        self.alternativeReturnPct = vm.alternativeReturnPct
        self.includeInflation = vm.includeInflation
        self.inflationRate = vm.inflationRate
        self.useRentAsExtraPayments = vm.useRentAsExtraPayments
        self.finalBalance = vm.finalBalance
        self.breakEvenYear = vm.breakEvenYear
        self.monthlyPayment = vm.monthlyPayment
        self.totalInterest = vm.totalInterest
    }

    /// Načte scénář do ViewModelu.
    func apply(to vm: MortgageViewModel) {
        vm.propertyPrice = propertyPrice
        vm.ownCapitalPct = ownCapitalPct
        vm.includeReconstruction = includeReconstruction
        vm.reconstructionAmount = reconstructionAmount
        vm.includeAppreciation = includeAppreciation
        vm.propertyAppreciationPct = propertyAppreciationPct
        vm.mortgageYears = mortgageYears
        vm.interestRate = interestRate
        vm.useRefixation = useRefixation
        vm.refixYear = refixYear
        vm.refixRate = refixRate
        vm.monthlyRent = monthlyRent
        vm.rentGrowthPct = rentGrowthPct
        vm.vacancyMonths = vacancyMonths
        vm.includeManagement = includeManagement
        vm.managementFeePct = managementFeePct
        vm.annualInsurance = annualInsurance
        vm.monthlySVJ = monthlySVJ
        vm.annualRepairs = annualRepairs
        vm.largeRepairAmount = largeRepairAmount
        vm.largeRepairEveryNYears = largeRepairEveryNYears
        vm.includeTax = includeTax
        vm.taxMode = taxMode
        vm.taxRate = taxRate
        vm.includeOpportunityCost = includeOpportunityCost
        vm.alternativeReturnPct = alternativeReturnPct
        vm.includeInflation = includeInflation
        vm.inflationRate = inflationRate
        vm.useRentAsExtraPayments = useRentAsExtraPayments
    }
}

// MARK: - Scenario Store

/// Persistentní úložiště scénářů (UserDefaults).
/// didSet nefunguje spolehlivě s @Observable — save() se volá explicitně.
@Observable
class ScenarioStore {
    static let shared = ScenarioStore()

    var scenarios: [MortgageScenario] = []

    private let key = "savedScenarios"

    private init() {
        load()
    }

    func add(_ scenario: MortgageScenario) {
        scenarios.append(scenario)
        save()
    }

    func remove(id: UUID) {
        scenarios.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(scenarios) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MortgageScenario].self, from: data) else { return }
        scenarios = decoded
    }
}
