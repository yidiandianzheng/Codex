// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexPetEnergy",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CodexPetEnergy", targets: ["CodexPetEnergy"]),
    ],
    targets: [
        .executableTarget(name: "CodexPetEnergy"),
    ],
    swiftLanguageModes: [.v5]
)
