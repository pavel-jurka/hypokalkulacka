/// ScenarioManagerView.swift — Správa a porovnání scénářů

import SwiftUI

struct ScenarioManagerView: View {
    @Bindable var vm: MortgageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var compareA: MortgageScenario?
    @State private var compareB: MortgageScenario?

    var store = ScenarioStore.shared

    var body: some View {
        NavigationStack {
            List {
                // MARK: Uložit aktuální
                Section {
                    HStack {
                        TextField("Název scénáře", text: $newName)
                        Button("Uložit") {
                            guard !newName.isEmpty else { return }
                            store.add(MortgageScenario(name: newName, vm: vm))
                            newName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newName.isEmpty)
                    }
                } header: { Text("Uložit aktuální nastavení") }

                // MARK: Porovnání
                if store.scenarios.count >= 2 {
                    Section {
                        Picker("Scénář A", selection: $compareA) {
                            Text("Vyberte").tag(nil as MortgageScenario?)
                            ForEach(store.scenarios) { s in
                                Text(s.name).tag(s as MortgageScenario?)
                            }
                        }
                        Picker("Scénář B", selection: $compareB) {
                            Text("Vyberte").tag(nil as MortgageScenario?)
                            ForEach(store.scenarios) { s in
                                Text(s.name).tag(s as MortgageScenario?)
                            }
                        }

                        if let a = compareA, let b = compareB, a.id != b.id {
                            ScenarioComparisonView(a: a, b: b)
                        }
                    } header: { Text("Porovnání scénářů") }
                }

                // MARK: Uložené scénáře
                Section {
                    if store.scenarios.isEmpty {
                        Text("Žádné uložené scénáře")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.scenarios) { scenario in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(scenario.name).fontWeight(.semibold)
                                    Text("\(czk(scenario.propertyPrice)) · \(String(format: "%.2f %%", scenario.interestRate)) · \(Int(scenario.mortgageYears)) let")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(czk(scenario.finalBalance, compact: true))
                                        .fontWeight(.bold)
                                        .foregroundStyle(scenario.finalBalance >= 0 ? .green : .red)
                                    Text("splátka \(czk(scenario.monthlyPayment, compact: true))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            HStack(spacing: 12) {
                                Button("Načíst") {
                                    scenario.apply(to: vm)
                                    dismiss()
                                }
                                .font(.caption).buttonStyle(.bordered)

                                Button("Smazat", role: .destructive) {
                                    store.remove(id: scenario.id)
                                }
                                .font(.caption).buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: { Text("Uložené scénáře (\(store.scenarios.count))") }
            }
            .navigationTitle("Scénáře")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zavřít") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Comparison View

struct ScenarioComparisonView: View {
    let a: MortgageScenario
    let b: MortgageScenario

    var body: some View {
        VStack(spacing: 8) {
            CompareRow("Cena nemovitosti", czk(a.propertyPrice, compact: true), czk(b.propertyPrice, compact: true))
            CompareRow("Úrok", String(format: "%.2f %%", a.interestRate), String(format: "%.2f %%", b.interestRate))
            CompareRow("Délka", "\(Int(a.mortgageYears)) let", "\(Int(b.mortgageYears)) let")
            CompareRow("Splátka", czk(a.monthlyPayment, compact: true), czk(b.monthlyPayment, compact: true))
            CompareRow("Nájem", czk(a.monthlyRent, compact: true), czk(b.monthlyRent, compact: true))
            CompareRow("Celkem úroky", czk(a.totalInterest, compact: true), czk(b.totalInterest, compact: true))

            Divider()

            HStack {
                Text(a.name).font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
                Text("vs").font(.caption2).foregroundStyle(.secondary)
                Text(b.name).font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity)
            }

            HStack {
                Text(czk(a.finalBalance, compact: true))
                    .fontWeight(.bold)
                    .foregroundStyle(a.finalBalance >= 0 ? .green : .red)
                    .frame(maxWidth: .infinity)

                let diff = b.finalBalance - a.finalBalance
                Text((diff >= 0 ? "+" : "") + czk(diff, compact: true))
                    .font(.caption).foregroundStyle(diff >= 0 ? .green : .red)

                Text(czk(b.finalBalance, compact: true))
                    .fontWeight(.bold)
                    .foregroundStyle(b.finalBalance >= 0 ? .green : .red)
                    .frame(maxWidth: .infinity)
            }

            if let ya = a.breakEvenYear, let yb = b.breakEvenYear {
                CompareRow("Bod zvratu", "rok \(ya)", "rok \(yb)")
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CompareRow: View {
    let label: String
    let valueA: String
    let valueB: String

    init(_ label: String, _ a: String, _ b: String) {
        self.label = label; self.valueA = a; self.valueB = b
    }

    var body: some View {
        HStack {
            Text(valueA).font(.caption).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 100)
            Text(valueB).font(.caption).monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
