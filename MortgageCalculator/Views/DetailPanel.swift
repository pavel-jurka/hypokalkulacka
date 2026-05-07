/// DetailPanel.swift — Pravý panel (snapshot, grafy/tabulka, PDF export)

import SwiftUI

struct DetailPanel: View {
    @Bindable var vm: MortgageViewModel
    @State private var selectedTab = 0
    @State private var pdfURL: URL?
    @State private var showPDFSheet = false

    var body: some View {
        VStack(spacing: 0) {
            SnapshotHeader(vm: vm)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Graf").tag(0)
                    Text("Tabulka").tag(1)
                }
                .pickerStyle(.segmented)

                Spacer()

                Button {
                    pdfURL = vm.generatePDF()
                    showPDFSheet = pdfURL != nil
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if selectedTab == 0 {
                ChartPanel(vm: vm)
            } else {
                YearTable(vm: vm)
            }
        }
        .sheet(isPresented: $showPDFSheet) {
            if let url = pdfURL {
                VStack(spacing: 20) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)
                    Text("PDF je připraveno")
                        .font(.title2).fontWeight(.semibold)
                    Text("MortgageCalculator.pdf")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ShareLink(
                        item: url,
                        preview: SharePreview(
                            "MortgageCalculator.pdf",
                            icon: Image(systemName: "doc.richtext.fill"))
                    ) {
                        Label("Sdílet / Uložit do souborů", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)

                    Button("Zavřít") { showPDFSheet = false }
                        .foregroundStyle(.secondary)
                }
                .padding(32)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}
