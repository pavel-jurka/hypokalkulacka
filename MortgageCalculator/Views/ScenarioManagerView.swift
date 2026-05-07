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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Scénáře").font(.title2).fontWeight(.bold)
                Spacer()
                Button("Zavřít") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                // MARK: Uložit aktuální
                Section("Uložit aktuální nastavení") {
                    HStack {
                        TextField("Název scénáře", text: $newName)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            guard !newName.isEmpty else { return }
                            store.add(MortgageScenario(name: newName, vm: vm))
                            newName = ""
                        } label: {
                            Label("Uložit", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newName.isEmpty)
                    }
                }

                // MARK: Porovnání
                if store.scenarios.count >= 2 {
                    Section("Porovnání scénářů") {
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
                    }
                }

                // MARK: Uložené scénáře
                Section("Uložené scénáře (\(store.scenarios.count))") {
                    if store.scenarios.isEmpty {
                        Text("Žádné uložené scénáře. Zadejte název a klepněte na Uložit.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    ForEach(store.scenarios) { scenario in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scenario.name).fontWeight(.semibold)
                                Text("\(czk(scenario.propertyPrice, compact: true)) · \(String(format: "%.2f %%", scenario.interestRate)) · \(Int(scenario.mortgageYears)) let")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(czk(scenario.finalBalance, compact: true))
                                    .fontWeight(.bold)
                                    .foregroundStyle(scenario.finalBalance >= 0 ? .green : .red)
                                Text("splátka \(czk(scenario.monthlyPayment, compact: true))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 8) {
                                Button {
                                    scenario.apply(to: vm)
                                    dismiss()
                                } label: {
                                    Image(systemName: "arrow.down.doc")
                                }
                                .buttonStyle(.bordered).tint(.blue)

                                Button(role: .destructive) {
                                    store.remove(id: scenario.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered).tint(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .presentationDetents([.large])
    }
}

// MARK: - Comparison View

struct ScenarioComparisonView: View {
    let a: MortgageScenario
    let b: MortgageScenario

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(a.name).font(.caption).fontWeight(.bold).frame(maxWidth: .infinity)
                Text("").frame(width: 100)
                Text(b.name).font(.caption).fontWeight(.bold).frame(maxWidth: .infinity)
            }

            Divider()

            CompareRow("Cena", czk(a.propertyPrice, compact: true), czk(b.propertyPrice, compact: true))
            CompareRow("Úrok", String(format: "%.2f %%", a.interestRate), String(format: "%.2f %%", b.interestRate))
            CompareRow("Délka", "\(Int(a.mortgageYears)) let", "\(Int(b.mortgageYears)) let")
            CompareRow("Splátka", czk(a.monthlyPayment, compact: true), czk(b.monthlyPayment, compact: true))
            CompareRow("Nájem", czk(a.monthlyRent, compact: true), czk(b.monthlyRent, compact: true))
            CompareRow("Úroky celkem", czk(a.totalInterest, compact: true), czk(b.totalInterest, compact: true))

            Divider()

            HStack {
                Text(czk(a.finalBalance, compact: true))
                    .fontWeight(.bold)
                    .foregroundStyle(a.finalBalance >= 0 ? .green : .red)
                    .frame(maxWidth: .infinity)

                let diff = b.finalBalance - a.finalBalance
                VStack {
                    Text("Čistý výsledek").font(.caption2).foregroundStyle(.secondary)
                    Text((diff >= 0 ? "+" : "") + czk(diff, compact: true))
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(diff >= 0 ? .green : .red)
                }
                .frame(width: 100)

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
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 100, alignment: .center)
            Text(valueB).font(.caption).monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
