import ProjectDescription

let developmentTeam = Environment.developmentTeam.getString(default: "")

let project = Project(
    name: "Boopa",
    options: .options(
        defaultKnownRegions: ["en", "zh-Hans"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": .string(developmentTeam),
        ],
        configurations: [
            .debug(name: "Debug", settings: [:], xcconfig: nil),
            .release(name: "Release", settings: [:], xcconfig: nil),
        ]
    ),
    targets: [
        .target(
            name: "Boopa",
            destinations: [.mac],
            product: .app,
            bundleId: "com.eilgnaw.boopa",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "LSUIElement": true,
                "CFBundleDisplayName": "Boopa",
                "LSApplicationCategoryType": "public.app-category.developer-tools",
                // Boopa is launched headless as a CLI too; never show a default window/menu.
                "NSPrincipalClass": "NSApplication",
            ]),
            sources: [.glob("Boopa/**", excluding: ["Boopa/Assets.xcassets/**"])],
            resources: .resources([
                .glob(pattern: "Boopa/Assets.xcassets/**"),
                .glob(pattern: "Boopa/Localizable.xcstrings"),
            ]),
            dependencies: [
                .external(name: "ArgumentParser"),
                .external(name: "TOMLKit"),
            ],
            settings: .settings(
                base: [
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "CODE_SIGN_STYLE": "Automatic",
                    "ENABLE_HARDENED_RUNTIME": "YES",
                    "COMBINE_HIDPI_IMAGES": "YES",
                    "CURRENT_PROJECT_VERSION": "1",
                    "MARKETING_VERSION": "1.0",
                    "PRODUCT_NAME": "Boopa",
                    "SWIFT_VERSION": "5.0",
                    "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
                    "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
                    "SWIFT_EMIT_LOC_STRINGS": "YES",
                ]
            )
        ),
    ]
)
