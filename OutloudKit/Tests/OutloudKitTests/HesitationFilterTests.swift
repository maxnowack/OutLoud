import Testing

@testable import OutloudKit

struct HesitationFilterTests {
    @Test(arguments: [
        (
            "So, um, I just wanted to let you know that the meeting is, uh, tomorrow at 3.",
            "So, I just wanted to let you know that the meeting is, tomorrow at 3."
        ),
        ("Äh, nein, streich das, um 4 Uhr.", "Nein, streich das, um 4 Uhr."),
        ("Also, ähm, ich wollte nur kurz sagen.", "Also, ich wollte nur kurz sagen."),
        ("Das ist gut, hm.", "Das ist gut."),
        ("Ähm. Hallo.", "Hallo."),
        ("Er, nein, streich das.", "Nein, streich das."),
    ])
    func removesHesitationSoundsAndTheirCommas(input: String, expected: String) {
        #expect(HesitationFilter.apply(to: input) == expected)
    }

    @Test func keepsFillersThatCanCarryMeaning() {
        let text = "I like it, also das ist halt so."
        #expect(HesitationFilter.apply(to: text) == text)
    }

    @Test func keepsWordsThatOnlyStartLikeASound() {
        let text = "Ehmke und Umberto kommen um acht."
        #expect(HesitationFilter.apply(to: text) == text)
    }
}
