import Foundation

/// A compatible model Clide found somewhere other than its own storage.
struct DiscoveredModel: Identifiable, Sendable, Equatable {
    var id: String { url.path }
    let url: URL
    let engineIdentifier: String
    let runtime: TranscriptionRuntime
    /// Where it came from, in words the user will recognise.
    let locationDescription: String
}

/// Finds compatible models the user already has, so Clide doesn't make them
/// download a second copy (clide.md §15).
///
/// Only a fixed allowlist of locations that these runtimes are actually known
/// to use is inspected. Clide never crawls arbitrary user folders.
enum ExistingModelDiscovery {
    private struct SearchLocation {
        let url: URL
        let runtime: TranscriptionRuntime
        let description: String
    }

    private static var searchLocations: [SearchLocation] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            // WhisperKit's own default download location.
            SearchLocation(
                url: home.appending(path: "Documents/huggingface/models/argmaxinc/whisperkit-coreml"),
                runtime: .whisperKit,
                description: "WhisperKit's default folder"
            ),
            SearchLocation(
                url: home.appending(path: ".cache/huggingface/hub/models--argmaxinc--whisperkit-coreml/snapshots"),
                runtime: .whisperKit,
                description: "your Hugging Face cache"
            ),
            SearchLocation(
                url: home.appending(path: "Library/Application Support/FluidAudio/Models"),
                runtime: .fluidAudio,
                description: "FluidAudio's folder"
            ),
        ]
    }

    /// Directories in known locations whose names match a catalogued model.
    static func discover() -> [DiscoveredModel] {
        var found: [DiscoveredModel] = []

        for location in searchLocations {
            guard FileManager.default.fileExists(atPath: location.url.path) else { continue }

            for directory in subdirectories(of: location.url) {
                let name = directory.lastPathComponent.lowercased()
                let match = ModelCatalog.all.first { model in
                    model.runtime == location.runtime
                        && (name == model.engineIdentifier.lowercased()
                            || name.contains(model.engineIdentifier.lowercased()))
                }
                guard let match else { continue }

                found.append(
                    DiscoveredModel(
                        url: directory,
                        engineIdentifier: match.engineIdentifier,
                        runtime: location.runtime,
                        locationDescription: location.description
                    )
                )
            }
        }
        return found
    }

    /// Snapshot directories nest one level deeper, so look through both.
    private static func subdirectories(of url: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let directories = contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }

        return directories + directories.flatMap { child in
            ((try? FileManager.default.contentsOfDirectory(
                at: child,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []).filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            }
        }
    }
}
