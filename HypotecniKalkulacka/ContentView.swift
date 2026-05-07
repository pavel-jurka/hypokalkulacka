/// ContentView.swift — HypotecniKalkulacka
///
/// Root view — NavigationSplitView s levým a pravým panelem.
/// Všechny sub-views jsou v Views/ adresáři.

import SwiftUI

struct ContentView: View {
    @State private var vm = MortgageViewModel()

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            InputPanel(vm: vm)
                .navigationTitle("Parametry")
                .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        } detail: {
            DetailPanel(vm: vm)
                .navigationTitle("Přehled")
        }
    }
}
