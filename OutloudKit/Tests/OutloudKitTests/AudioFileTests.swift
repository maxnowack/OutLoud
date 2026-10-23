import Testing

@testable import OutloudKit

struct AudioFileTests {
    @Test(arguments: [("Recording.m4a", "m4a"), ("memo.WAV", "wav"), ("a.b.caf", "caf")])
    func keepsAPlainExtension(name: String, expected: String) {
        #expect(AudioFile.fileExtension(of: name) == expected)
    }

    @Test(arguments: [
        "x./../../escape", "x.m4a/../../escape", "../../escape", "x.m 4a", "x.m4a\u{0}",
        "x.verylongextension", "x.", "noextension", "x.äöü",
    ])
    func refusesAnExtensionThatIsNotPlain(name: String) {
        #expect(AudioFile.fileExtension(of: name) == "m4a")
    }
}
