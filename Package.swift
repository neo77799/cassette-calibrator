// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CassetteCalibrator",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CassetteCalibrator",
            targets: ["CassetteCalibrator"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CassetteCalibrator"
        )
    ]
)
