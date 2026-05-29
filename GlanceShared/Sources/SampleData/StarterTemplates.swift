import Foundation

// MARK: - StarterTemplates
/// Pre-filled themes shown on first launch so the user never faces a blank screen.
enum StarterTemplates {
    static func all() -> [Theme] {
        [
            Theme(
                name: "Take meds",
                colorToken: "sage",
                iconEmoji: "💊",
                sortOrder: 0,
                steps: [
                    Step(text: "Get water", iconEmoji: "💧", sortOrder: 0),
                    Step(text: "Take tablets", iconEmoji: "💊", sortOrder: 1),
                    Step(text: "Put bottle back", sortOrder: 2),
                ]
            ),
            Theme(
                name: "Leave the house",
                colorToken: "sky",
                iconEmoji: "🚪",
                sortOrder: 1,
                steps: [
                    Step(text: "Grab keys", iconEmoji: "🔑", sortOrder: 0),
                    Step(text: "Phone charged?", iconEmoji: "🔋", sortOrder: 1),
                    Step(text: "Bag packed", iconEmoji: "🎒", sortOrder: 2),
                    Step(text: "Lock the door", iconEmoji: "🔒", sortOrder: 3),
                ]
            ),
            Theme(
                name: "Morning",
                colorToken: "butter",
                iconEmoji: "☀️",
                sortOrder: 2,
                steps: [
                    Step(text: "Drink water", iconEmoji: "💧", sortOrder: 0),
                    Step(text: "Wash face", sortOrder: 1),
                    Step(text: "Get dressed", sortOrder: 2),
                    Step(text: "Eat something", iconEmoji: "🍞", sortOrder: 3),
                ]
            ),
        ]
    }
}
