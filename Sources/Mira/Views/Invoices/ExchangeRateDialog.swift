import SwiftUI
import os

/// Asks for the exchange rate when a foreign-currency invoice is paid, so the
/// dashboard can count what was actually received in the base currency.
struct ExchangeRateDialog: View {
    let invoice: Invoice
    let baseCurrency: Currency
    var isVatExempt: Bool = false
    let onConfirm: (_ rate: Double, _ amountInBaseCurrency: Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rateText = ""
    @State private var isLoading = true
    @State private var fetchError: String?
    @State private var isLiveRate = false

    private var invoiceTotal: Double { isVatExempt ? invoice.subtotal : invoice.total }
    private var rate: Double? {
        let value = Double(rateText.replacingOccurrences(of: ",", with: "."))
        return (value ?? 0) > 0 ? value : nil
    }
    private var converted: Double? { rate.map { invoiceTotal * $0 } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Invoice total") {
                        MoneyText(invoiceTotal, invoice.currency, weight: .medium)
                    }
                    LabeledContent("Exchange rate") {
                        HStack(spacing: Spacing.s) {
                            Text("1 \(invoice.currency.rawValue) =")
                                .foregroundStyle(.secondary)
                            TextField("0.0000", text: $rateText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 96)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                            Text(baseCurrency.rawValue)
                                .foregroundStyle(.secondary)
                            Button("Refresh", systemImage: "arrow.clockwise") {
                                Task { await fetchRate() }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .disabled(isLoading)
                        }
                    }
                    LabeledContent("You received") {
                        if let converted {
                            MoneyText(converted, baseCurrency, font: .title3, weight: .semibold)
                        } else {
                            Text("—").foregroundStyle(.tertiary)
                        }
                    }
                } footer: {
                    if isLoading {
                        HStack(spacing: Spacing.s) {
                            ProgressView().controlSize(.small)
                            Text("Fetching today's rate…")
                        }
                    } else if let fetchError {
                        Text("\(fetchError) Enter the rate from your bank statement instead.")
                    } else if isLiveRate {
                        Text("Today's rate from the European Central Bank. Adjust it to match what your bank actually paid out.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Mark as paid in \(baseCurrency.rawValue)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mark as paid") {
                        if let rate, let converted {
                            onConfirm(rate, converted)
                            dismiss()
                        }
                    }
                    .disabled(rate == nil)
                }
            }
        }
        .frame(width: 440, height: 300)
        .task { await fetchRate() }
    }

    private func fetchRate() async {
        isLoading = true
        fetchError = nil
        isLiveRate = false
        defer { isLoading = false }

        let from = invoice.currency.rawValue
        let to = baseCurrency.rawValue
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=\(from)&to=\(to)") else {
            fetchError = "Unsupported currency pair."
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rates = json["rates"] as? [String: Double],
                  let rate = rates[to] else {
                fetchError = "The rate service returned an unexpected answer."
                return
            }
            rateText = String(format: "%.4f", rate)
            isLiveRate = true
        } catch {
            Log.app.error("Exchange rate fetch failed: \(error.localizedDescription, privacy: .public)")
            fetchError = "Couldn't reach the rate service."
        }
    }
}
