import Foundation

// MARK: - StarterTemplates
/// Pre-filled themes shown on first launch so the user never faces a blank screen.
enum StarterTemplates {
    static func all() -> [Theme] {
        [
            Theme(
                name: "Take meds",
                colorToken: "sage",
                iconToken: "meds",
                sortOrder: 0,
                steps: [
                    Step(text: "Pour a full glass of water", sortOrder: 0),
                    Step(text: "Take the morning tablets", sortOrder: 1),
                    Step(text: "Put the bottle back in the cabinet", sortOrder: 2),
                ]
            ),
            Theme(
                name: "Leave the house",
                colorToken: "sky",
                iconToken: "leave",
                sortOrder: 1,
                steps: [
                    Step(text: "Keys from the bowl by the door", sortOrder: 0),
                    Step(text: "Phone off the charger", sortOrder: 1),
                    Step(text: "Work badge clipped to the bag", sortOrder: 2),
                    Step(text: "Lock the deadbolt, not just the handle", sortOrder: 3),
                ]
            ),
            Theme(
                name: "Morning",
                colorToken: "butter",
                iconToken: "morning",
                sortOrder: 2,
                steps: [
                    Step(text: "Drink a glass of water", sortOrder: 0),
                    Step(text: "Wash face and brush teeth", sortOrder: 1),
                    Step(text: "Get dressed", sortOrder: 2),
                    Step(text: "Eat something, even if small", sortOrder: 3),
                ]
            ),
        ]
    }
}
