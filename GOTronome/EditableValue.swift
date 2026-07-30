//
//  EditableValue.swift
//  GOTronome
//
//  Created by Paolo De Pascalis on 30.07.26.
//

import SwiftUI

private let valueFieldDigitWidth: CGFloat = 12
private let valueFieldPadding: CGFloat = 20

/// Shows `value` inside an outlined box that reads as a text field at rest, so a precise number
/// can be typed instead of hunted for with the slider. Committed on Done or on focus loss,
/// clamped to `range`, and left untouched if what was typed is not a number.
struct EditableValueView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    private var maxDigits: Int { String(Int(range.upperBound)).count }
    private var displayed: String { String(Int(value)) }

    private var borderColor: Color { isFocused ? .accentColor : .white.opacity(0.4) }
    private var borderWidth: CGFloat { isFocused ? 2 : 1 }
    private var fieldWidth: CGFloat { CGFloat(maxDigits) * valueFieldDigitWidth + valueFieldPadding }

    // Split out from body: the whole chain in one expression blows up the type checker.
    private var field: some View {
        TextField("", text: $draft, prompt: Text(displayed).foregroundColor(.white.opacity(0.4)))
            .textFieldStyle(.plain)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .tint(.accentColor)
            .focused($isFocused)
            .frame(width: fieldWidth)
            .padding(.vertical, 8)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: borderWidth)
    }

    var body: some View {
        field
            .overlay(border)
            .onAppear { draft = displayed }
            .onChange(of: value) { _ in
                if !isFocused { draft = displayed }
            }
            .onChange(of: draft) { typed in
                let digits = String(typed.filter(\.isNumber).prefix(maxDigits))
                if digits != typed { draft = digits }
            }
            .onChange(of: isFocused) { focused in
                // Clearing on focus means typing replaces the old value rather than appending to
                // it; the prompt keeps showing what it was until the first digit lands.
                if focused { draft = "" } else { commit() }
            }
            .toolbar {
                // numberPad has no return key, so Done is the only way to dismiss. The group is
                // registered unconditionally and its *content* is what depends on focus: an `if`
                // directly under .toolbar needs ToolbarContentBuilder.buildIf (iOS 16+), while
                // inside the group it is an ordinary ViewBuilder. Without this, every selector on
                // screen contributes its own Done button.
                ToolbarItemGroup(placement: .keyboard) {
                    if isFocused {
                        Spacer()
                        Button("Done") { isFocused = false }
                    }
                }
            }
    }

    private func commit() {
        guard let typed = Int(draft) else {
            draft = displayed
            return
        }
        let clamped = min(max(Double(typed), range.lowerBound), range.upperBound)
        value = clamped
        draft = String(Int(clamped))
    }
}

#Preview {
    HStack {
        Text("Beats Per Minute").foregroundColor(.white)
        Slider(value: .constant(120), in: 20...240).tint(.accentColor)
        EditableValueView(value: .constant(120), range: 20...240)
    }
    .padding()
    .background(Color.black)
}
