import Testing
@testable import Clide

struct ModelCatalogTests {
    @Test func modelIDsAreUnique() {
        let ids = ModelCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func defaultModelExistsInCatalog() {
        #expect(ModelCatalog.model(withID: ModelCatalog.defaultModelID) != nil)
    }

    @Test func cloudModelsRequireAKeyAndLocalOnesDoNot() {
        for model in ModelCatalog.all {
            let matches = model.requiresAPIKey == !model.isLocal
            #expect(matches)
        }
    }

    @Test func onlyCoreMLRuntimesClaimTheNeuralEngine() {
        for model in ModelCatalog.all {
            let expected = model.runtime == .whisperKit || model.runtime == .fluidAudio
            #expect(model.usesNeuralEngine == expected)
        }
    }

    /// Cloud models must not advertise a download or memory footprint.
    @Test func cloudModelsHaveNoLocalFootprint() {
        for model in ModelCatalog.all where !model.isLocal {
            #expect(model.downloadSizeMB == 0)
            #expect(model.recommendedMemoryGB == 0)
        }
    }

    @Test func downloadableModelsDeclareASize() {
        for model in ModelCatalog.all {
            if case .download = model.source {
                #expect(model.downloadSizeMB > 0)
            }
        }
    }

    @Test func scoresStayInRange() {
        for model in ModelCatalog.all {
            #expect((1...5).contains(model.accuracyScore))
            #expect((1...5).contains(model.speedScore))
        }
    }

    @Test func everyCloudProviderHasAtLeastOneModel() {
        for provider in CloudProvider.allCases {
            #expect(ModelCatalog.all.contains { $0.runtime == .cloud(provider) })
        }
    }

    @Test func downloadSizeFormattingSwitchesToGigabytes() {
        let large = ModelCatalog.model(withID: "whisper.large-v3-turbo")
        #expect(large?.formattedDownloadSize == "1.6 GB")
        let tiny = ModelCatalog.model(withID: "whisper.tiny.en")
        #expect(tiny?.formattedDownloadSize == "78 MB")
    }

    @Test func cloudAndSystemModelsDescribeTheirSizeHonestly() {
        #expect(ModelCatalog.model(withID: "groq.whisper-large-v3-turbo")?.formattedDownloadSize == "No download")
        #expect(ModelCatalog.model(withID: "apple.speech.system")?.formattedDownloadSize == "Built in")
    }
}

struct HardwareFitTests {
    private let appleSilicon = HardwareProfile(
        modelIdentifier: "Mac14,12",
        physicalMemoryBytes: 16 * 1_073_741_824,
        coreCount: 10,
        isAppleSilicon: true
    )

    private let oldIntelMac = HardwareProfile(
        modelIdentifier: "MacBookPro11,1",
        physicalMemoryBytes: 4 * 1_073_741_824,
        coreCount: 4,
        isAppleSilicon: false
    )

    @Test func ratingsAlwaysLandBetweenOneAndFiveStars() {
        for model in ModelCatalog.all {
            for hardware in [appleSilicon, oldIntelMac] {
                let fit = HardwareFit.evaluate(model: model, on: hardware)
                #expect((1...5).contains(fit.stars))
            }
        }
    }

    @Test func everyRatingExplainsItself() {
        for model in ModelCatalog.all {
            let fit = HardwareFit.evaluate(model: model, on: appleSilicon)
            #expect(!(fit.positives.isEmpty && fit.cautions.isEmpty))
            #expect(!fit.summary.isEmpty)
        }
    }

    @Test func aBigModelRatesWorseOnAWeakerMac() throws {
        let large = try #require(ModelCatalog.model(withID: "whisper.large-v3-turbo"))
        let good = HardwareFit.evaluate(model: large, on: appleSilicon)
        let poor = HardwareFit.evaluate(model: large, on: oldIntelMac)
        #expect(poor.stars < good.stars)
    }

    @Test func insufficientMemoryIsCalledOut() throws {
        let large = try #require(ModelCatalog.model(withID: "whisper.large-v3-turbo"))
        let fit = HardwareFit.evaluate(model: large, on: oldIntelMac)
        #expect(fit.cautions.contains { $0.contains("16 GB") })
    }

    /// Cloud models must always say the audio leaves the Mac.
    @Test func cloudRatingsWarnThatAudioLeavesTheMac() {
        for model in ModelCatalog.all where !model.isLocal {
            let fit = HardwareFit.evaluate(model: model, on: appleSilicon)
            #expect(fit.cautions.contains { $0.localizedCaseInsensitiveContains("sent to") })
        }
    }

    @Test func neuralEngineIsCreditedOnlyWhenPresent() throws {
        let parakeet = try #require(ModelCatalog.model(withID: "fluid.parakeet-tdt-0.6b-v2"))
        let onSilicon = HardwareFit.evaluate(model: parakeet, on: appleSilicon)
        let onIntel = HardwareFit.evaluate(model: parakeet, on: oldIntelMac)
        #expect(onSilicon.positives.contains { $0.contains("Neural Engine") })
        #expect(onIntel.cautions.contains { $0.contains("Neural Engine") })
    }
}

struct CloudProviderTests {
    @Test func eachProviderUsesItsOwnAuthScheme() {
        #expect(CloudProvider.groq.authorizationHeader(for: "k").value == "Bearer k")
        #expect(CloudProvider.deepgram.authorizationHeader(for: "k").value == "Token k")
        #expect(CloudProvider.assemblyAI.authorizationHeader(for: "k").value == "k")
    }

    @Test func allProvidersAuthenticateViaTheAuthorizationHeader() {
        for provider in CloudProvider.allCases {
            #expect(provider.authorizationHeader(for: "k").field == "Authorization")
        }
    }

    @Test func errorsReadAsPlainAdviceNotJargon() {
        let message = CloudProviderError.missingKey(.deepgram).errorDescription ?? ""
        #expect(message.contains("Deepgram"))
        #expect(message.contains("Settings"))
    }
}
