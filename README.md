# LumaSpace

LumaSpace is an iOS interior-design companion that helps people turn a room into a plan: scan spaces with RoomPlan/LiDAR, explore AI-assisted concepts, compare designs, place furniture in AR, build moodboards, and keep projects organized.

> LumaSpace is a design and visualization tool. AI suggestions, measurements, and product information should be reviewed by the user before making purchasing or construction decisions.

<p align="center">
  <a href="https://buymeacoffee.com/awaisdev572">
    <img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=%E2%98%95&slug=awaisdev572&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" alt="Buy me a coffee" height="60">
  </a>
</p>

## What you can do

- Create and manage room-design projects
- Scan compatible rooms with RoomPlan and LiDAR
- Generate AI design concepts and future-vision variations
- Compare concepts with before/after interactions
- Place furniture in augmented reality and preview items with Quick Look
- Build color palettes, moodboards, and shareable design cards
- Browse a furniture catalog with shopping and affiliate integration points
- Export design PDFs and use widgets, notifications, and Spotlight integration
- Use StoreKit configuration for subscription and lifetime-product testing

## Tech stack

- Swift 5.10 and SwiftUI
- iOS 17+
- ARKit, RealityKit, RoomPlan, PDFKit, PhotosUI, CloudKit, TipKit, StoreKit
- WidgetKit app extension
- XcodeGen project definition in `project.yml`

## Repository map

```text
LumaSpace/
├── LumaSpace.xcodeproj/       # Xcode project
├── project.yml                # XcodeGen source of truth
├── LumaSpace/
│   ├── App/                   # App entry point, Info.plist, entitlements
│   ├── Core/                  # Models, design system, services, configuration
│   ├── Features/              # Home, scan, AR, designs, catalog, profile, etc.
│   └── Resources/             # Assets and StoreKit configuration
├── LumaSpaceWidget/           # WidgetKit extension
└── setup.sh                   # Local setup helper
```

## Requirements

- macOS with Xcode 15.4 or newer
- iOS 17 or newer
- A LiDAR-capable iPhone/iPad is required for RoomPlan scanning and the full AR workflow
- XcodeGen is optional if you need to regenerate the project from `project.yml`

## Run locally

1. Clone the repository and open `LumaSpace.xcodeproj`.
2. Select the **LumaSpace** scheme and an iOS 17+ destination.
3. Configure your Apple Developer team and signing for the app and widget targets.
4. Press **Run** (`⌘R`).

To regenerate the project after editing `project.yml`:

```bash
xcodegen generate
```

To build for a simulator:

```bash
xcodebuild \
  -project LumaSpace.xcodeproj \
  -scheme LumaSpace \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -configuration Debug \
  build
```

RoomPlan, LiDAR, camera, and AR placement should be tested on compatible physical hardware. Simulator support is useful for navigation, design browsing, StoreKit configuration, and most non-camera flows.

## Configuration and security

The app intentionally ships with an empty `openAIKey`. Do not paste API keys into `Config.swift` or commit them to Git. Use a secure server-side proxy or local-only Xcode configuration when adding AI credentials. Review entitlements, CloudKit containers, StoreKit products, affiliate IDs, privacy URLs, and notification settings before distribution.

The repository ignores `.claude/`, local settings, environment files, Firebase files, signing material, and generated Xcode output.

## Roadmap

- [ ] Add a secure backend proxy for AI requests and per-user rate limits
- [ ] Persist room scans and projects with CloudKit sync and conflict handling
- [ ] Add a complete LiDAR scan review/edit flow before saving floor plans
- [ ] Improve AR anchoring, furniture occlusion, and multi-item placement
- [ ] Add design-version history with restore and side-by-side comparison
- [ ] Add furniture availability, price refresh, and transparent affiliate disclosure
- [ ] Expand widgets, Siri/App Intents, and Spotlight actions
- [ ] Add localization, Dynamic Type coverage, and a full VoiceOver audit
- [ ] Add unit/UI tests and a pull-request CI build
- [ ] Ship TestFlight beta onboarding and collect structured design feedback

## Contributing

Create a focused feature branch, keep secrets out of commits, test on both Simulator and compatible hardware when relevant, and include screenshots or a short recording for meaningful UI/AR changes.

## Support

If LumaSpace helps you plan a better room, you can support continued development with a coffee using the button above. Contributions help fund device testing, AR improvements, accessibility work, and future releases.

## License

No license has been selected yet. Until one is added, all rights are reserved by the project owner.
