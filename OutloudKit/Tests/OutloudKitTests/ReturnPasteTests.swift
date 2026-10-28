import Testing

@testable import OutloudKit

struct ReturnPasteTests {
    /// A focused field as the app describes it: the element, and the conversation it shows.
    private struct Field: Equatable {
        let element: Int
        let conversation: String
    }

    private let chat = Field(element: 1, conversation: "session A")

    @Test func pastesAtOnceWhenTheUserStayedInTheField() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        #expect(paste.check(focused: chat) == nil)
        #expect(paste.finish(ticket, "Hello", focused: chat) == .paste("Hello"))
        #expect(!paste.isActive)
    }

    @Test func leavingTheFieldShowsTheNoticeOnceAndPastesOnReturn() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        #expect(paste.check(focused: nil) == .showWaitingNotice)
        #expect(paste.check(focused: nil) == nil)
        #expect(paste.finish(ticket, "Hello", focused: nil) == nil)
        #expect(paste.check(focused: chat) == .paste("Hello"))
        #expect(paste.check(focused: chat) == nil)
        #expect(!paste.isActive)
    }

    @Test func aResultReadyAfterTheUserLeftShowsTheNotice() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        #expect(paste.finish(ticket, "Hello", focused: nil) == .showWaitingNotice)
        #expect(paste.isActive)
    }

    @Test func anotherFieldOfTheSameAppKeepsTheResultWaiting() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        _ = paste.finish(ticket, "Hello", focused: nil)
        #expect(paste.check(focused: Field(element: 2, conversation: "session A")) == nil)
        #expect(paste.waiting?.text == "Hello")
    }

    @Test func theSameFieldShowingAnotherConversationKeepsTheResultWaiting() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        _ = paste.finish(ticket, "Hello", focused: nil)
        #expect(paste.check(focused: Field(element: 1, conversation: "session B")) == nil)
        #expect(paste.check(focused: chat) == .paste("Hello"))
    }

    @Test func aNewerDictationReplacesAWaitingResult() {
        var paste = ReturnPaste<Field>()
        let old = paste.start(in: chat)
        _ = paste.finish(old, "Old", focused: nil)
        let other = Field(element: 3, conversation: "mail")
        let new = paste.start(in: other)
        #expect(paste.finish(new, "New", focused: nil) == .showWaitingNotice)
        #expect(paste.check(focused: chat) == nil)
        #expect(paste.check(focused: other) == .paste("New"))
    }

    @Test func anOlderDictationThatFinishesLateLeavesTheNewerAlone() {
        var paste = ReturnPaste<Field>()
        let old = paste.start(in: chat)
        let other = Field(element: 3, conversation: "mail")
        let new = paste.start(in: other)
        #expect(paste.finish(old, "Old", focused: chat) == nil)
        paste.fail(old)
        #expect(paste.processed == other)
        #expect(paste.finish(new, "New", focused: other) == .paste("New"))
    }

    @Test func aFailedDictationWaitsForNothing() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        paste.fail(ticket)
        #expect(!paste.isActive)
        #expect(paste.finish(ticket, "Late", focused: chat) == nil)
    }
}
