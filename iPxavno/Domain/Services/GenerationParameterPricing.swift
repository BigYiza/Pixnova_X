import Foundation

struct GenerationParameterSelection {
    let parameter: GenerationParameter
    var selectedIndex: Int

    var selectedValue: GenerationParameterValue? {
        guard parameter.values.indices.contains(selectedIndex) else { return nil }
        return parameter.values[selectedIndex]
    }
}

final class GenerationParameterPricing {
    private let baseDiamondCost: Int
    private let restrictions: [GenerationParameterRestriction]
    private let optionalDuration: Double?

    private(set) var selections: [GenerationParameterSelection]
    private(set) var expense: Int
    private(set) var toastMessage: String?

    init(
        template: CreativeTemplate,
        optionalDuration: Double? = nil
    ) {
        baseDiamondCost = template.diamondCost
        restrictions = template.customParameter?.restricts ?? []
        self.optionalDuration = optionalDuration
        selections = (template.customParameter?.parameters ?? []).map { parameter in
            GenerationParameterSelection(
                parameter: parameter,
                selectedIndex: Self.defaultSelectedIndex(for: parameter)
            )
        }
        expense = max(0, template.diamondCost)
        refreshPrice()
    }

    var hasParameters: Bool {
        !selections.isEmpty
    }

    func select(parameterIndex: Int, valueIndex: Int) {
        guard selections.indices.contains(parameterIndex),
              selections[parameterIndex].parameter.values.indices.contains(valueIndex) else {
            return
        }

        toastMessage = nil
        selections[parameterIndex].selectedIndex = valueIndex
        let selectedValue = selections[parameterIndex].parameter.values[valueIndex]
        applyDirectRestrictions(for: selectedValue)
        applyReverseRestrictions(mainParameterKey: selections[parameterIndex].parameter.key, mainTargetValue: selectedValue)
        refreshPrice()
    }

    func consumeToastMessage() -> String? {
        let message = toastMessage
        toastMessage = nil
        return message
    }

    func externalArguments() -> [String: JSONValue] {
        var arguments: [String: JSONValue] = [:]

        selections.forEach { selection in
            guard let selectedValue = selection.selectedValue else { return }
            arguments[selection.parameter.key] = selectedValue.value
        }

        return arguments
    }

    private func applyDirectRestrictions(for selectedValue: GenerationParameterValue) {
        guard !restrictions.isEmpty else { return }

        let matchingRestrictions = restrictions.filter {
            Self.valuesEqual($0.value, selectedValue.value)
        }

        for restriction in matchingRestrictions {
            guard let relationValues = restriction.restricts.first else { continue }

            for (restrictedKey, allowedValues) in relationValues {
                guard let parameterIndex = selections.firstIndex(where: { $0.parameter.key == restrictedKey }),
                      let currentValue = selections[parameterIndex].selectedValue else {
                    continue
                }

                let isAllowed = allowedValues.contains { Self.valuesEqual($0, currentValue.value) }
                guard !isAllowed, let defaultValue = allowedValues.first else { continue }

                guard let targetIndex = selections[parameterIndex].parameter.values.firstIndex(where: {
                    Self.valuesEqual($0.value, defaultValue)
                }) else {
                    continue
                }

                selections[parameterIndex].selectedIndex = targetIndex
                queueToast(for: selections[parameterIndex])
            }
        }
    }

    private func applyReverseRestrictions(
        mainParameterKey: String,
        mainTargetValue: GenerationParameterValue
    ) {
        guard !restrictions.isEmpty else { return }

        for parameterIndex in selections.indices where selections[parameterIndex].parameter.key != mainParameterKey {
            guard let selectedMinorValue = selections[parameterIndex].selectedValue else { continue }

            let matchingRestrictions = restrictions.filter {
                $0.key == selections[parameterIndex].parameter.key &&
                Self.valuesEqual($0.value, selectedMinorValue.value)
            }

            for restriction in matchingRestrictions {
                guard let relationValues = restriction.restricts.first,
                      let mainAllowedValues = relationValues[mainParameterKey] else {
                    continue
                }

                let isAllowed = mainAllowedValues.contains {
                    Self.valuesEqual($0, mainTargetValue.value)
                }

                guard !isAllowed else { continue }

                let fallbackIndex = selections[parameterIndex].parameter.values.firstIndex { candidate in
                    candidateSupports(
                        candidate,
                        minorParameterKey: selections[parameterIndex].parameter.key,
                        mainParameterKey: mainParameterKey,
                        mainTargetValue: mainTargetValue
                    )
                } ?? 0

                selections[parameterIndex].selectedIndex = fallbackIndex
                queueToast(for: selections[parameterIndex])
            }
        }
    }

    private func candidateSupports(
        _ candidate: GenerationParameterValue,
        minorParameterKey: String,
        mainParameterKey: String,
        mainTargetValue: GenerationParameterValue
    ) -> Bool {
        let matchingRestrictions = restrictions.filter {
            $0.key == minorParameterKey && Self.valuesEqual($0.value, candidate.value)
        }

        guard !matchingRestrictions.isEmpty else { return true }

        for restriction in matchingRestrictions {
            guard let relationValues = restriction.restricts.first,
                  let mainAllowedValues = relationValues[mainParameterKey] else {
                return true
            }

            return mainAllowedValues.contains {
                Self.valuesEqual($0, mainTargetValue.value)
            }
        }

        return true
    }

    private func refreshPrice() {
        var multiplier = 1.0

        for selection in selections {
            guard let value = selection.selectedValue else { continue }

            if value.calculationMethod == GenerationParameterValue.videoBoostCalculationMethod {
                let durationTimes = Double(value.durationTimes ?? "1.0") ?? 1.0
                multiplier *= durationTimes * (optionalDuration ?? 1.0)
            }

            multiplier *= Double(value.times) ?? 1.0
        }

        expense = Int(Double(max(0, baseDiamondCost)) * multiplier)
    }

    private func queueToast(for selection: GenerationParameterSelection) {
        guard let selectedValue = selection.selectedValue else { return }
        toastMessage = "[\(selection.parameter.title)] was automatically updated to [\(selectedValue.label)] based on model requirements."
    }

    private static func defaultSelectedIndex(for parameter: GenerationParameter) -> Int {
        guard let selected = parameter.selected else { return 0 }
        return parameter.values.firstIndex {
            valuesEqual($0.value, selected) || valuesEqual(.string($0.label), selected)
        } ?? 0
    }

    private static func valuesEqual(_ lhs: JSONValue, _ rhs: JSONValue) -> Bool {
        lhs.normalizedComparableString == rhs.normalizedComparableString
    }
}
