import TipKit

// MARK: - First Scan Tip

struct FirstScanTip: Tip {
    var title: Text { Text("Start by scanning a room") }
    var message: Text? {
        Text("Tap Scan to capture your room's exact dimensions with your iPhone camera.")
    }
    var image: Image? { Image(systemName: "camera.viewfinder") }
    var actions: [Action] {
        [Action(id: "scan", title: "Open Scanner")]
    }
}

// MARK: - Generate Designs Tip

struct GenerateDesignsTip: Tip {
    static let roomScanned = Event(id: "room.scanned")

    var title: Text { Text("Your room is ready for AI design") }
    var message: Text? {
        Text("Select a style and tap Generate — AI creates personalised concepts in seconds.")
    }
    var image: Image? { Image(systemName: "wand.and.stars") }
    var rules: [Rule] {
        [#Rule(Self.roomScanned) { $0.donations.count >= 1 }]
    }
}

// MARK: - AR Placement Tip

struct ARPlacementTip: Tip {
    static let designGenerated = Event(id: "design.generated")

    var title: Text { Text("Place furniture in your room") }
    var message: Text? {
        Text("Tap the + button, pick any piece of furniture, then tap the floor to place it.")
    }
    var image: Image? { Image(systemName: "arkit") }
    var rules: [Rule] {
        [#Rule(Self.designGenerated) { $0.donations.count >= 1 }]
    }
}

// MARK: - Before After Tip

struct BeforeAfterTip: Tip {
    var title: Text { Text("Compare before and after") }
    var message: Text? {
        Text("Drag the slider left and right to compare your original room with the AI design.")
    }
    var image: Image? { Image(systemName: "arrow.left.arrow.right") }
    var options: [Option] { [MaxDisplayCount(3)] }
}

// MARK: - Moodboard Tip

struct MoodboardTip: Tip {
    var title: Text { Text("Build your vision board") }
    var message: Text? {
        Text("Save photos, colours, and textures here to build the mood for your space.")
    }
    var image: Image? { Image(systemName: "photo.stack") }
    var options: [Option] { [MaxDisplayCount(2)] }
}

// MARK: - Future Vision Tip (Premium)

struct FutureVisionTip: Tip {
    var title: Text { Text("See your room reimagined") }
    var message: Text? {
        Text("Future Vision uses DALL·E 3 to show what your space could look like with a luxury upgrade, budget makeover, and more.")
    }
    var image: Image? { Image(systemName: "sparkles") }
    var options: [Option] { [MaxDisplayCount(1)] }
}

// MARK: - Configure Tips

enum LumaTipsConfig {
    static func configure() {
        // Use .production for App Store, .previewTips in DEBUG
        #if DEBUG
        try? Tips.resetDatastore()
        try? Tips.configure([.displayFrequency(.immediate)])
        #else
        try? Tips.configure([.displayFrequency(.daily)])
        #endif
    }
}
