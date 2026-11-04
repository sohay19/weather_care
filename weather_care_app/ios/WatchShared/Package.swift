// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "WeatherCareWatchModel", products: [], targets: [
  .target(name: "WeatherCareWatchModel", path: ".", exclude: ["Tests", "Assets.xcassets", "WatchWeatherIcon.swift"], sources: ["WatchSnapshot.swift"]),
  .testTarget(name: "WeatherCareWatchModelTests", dependencies: ["WeatherCareWatchModel"], path: "Tests")
])
