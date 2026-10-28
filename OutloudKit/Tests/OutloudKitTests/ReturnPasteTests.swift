import Testing

@testable import OutloudKit

struct ReturnPasteTests {
    /// A focused field as the app describes it: the element, and the conversation it shows.
    private struct Field: Equatable {
        let element: Int
        let conversation: String
    }

    private let chat = Field(element: 1, conversation: "session A")
    private let mail = Field(element: 3, conversation: "mail")

    @Test func pastesAtOnceWhenTheUserStayedInTheField() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        #expect(!paste.goesToNextField(ticket))
        #expect(paste.check(focused: chat) == [])
        paste.finish(ticket, "Hello")
        #expect(paste.check(focused: chat) == [.paste("Hello")])
        #expect(!paste.isActive)
    }

    @Test func leavingTheFieldSaysSoOnceAndPastesOnReturn() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        #expect(paste.check(focused: nil) == [.leftField(ticket, chat)])
        #expect(paste.check(focused: mail) == [])
        paste.finish(ticket, "Hello")
        #expect(paste.check(focused: nil) == [])
        #expect(paste.check(focused: chat) == [.paste("Hello")])
        #expect(paste.check(focused: chat) == [])
        #expect(!paste.isActive)
    }

    @Test func aResultReadyAfterTheUserLeftSaysSo() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        paste.finish(ticket, "Hello")
        #expect(paste.check(focused: nil) == [.leftField(ticket, chat)])
        #expect(paste.isActive)
    }

    @Test func anotherFieldOfTheSameAppKeepsTheResultWaiting() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        paste.finish(ticket, "Hello")
        let other = Field(element: 2, conversation: "session A")
        #expect(paste.check(focused: other) == [.leftField(ticket, chat)])
        #expect(paste.check(focused: other) == [])
        #expect(paste.isActive)
    }

    @Test func theSameFieldShowingAnotherConversationKeepsTheResultWaiting() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        paste.finish(ticket, "Hello")
        #expect(
            paste.check(focused: Field(element: 1, conversation: "session B"))
                == [.leftField(ticket, chat)])
        #expect(paste.check(focused: chat) == [.paste("Hello")])
    }

    @Test func dictationsOfDifferentFieldsWaitSideBySide() {
        var paste = ReturnPaste<Field>()
        let first = paste.start(in: chat)
        _ = paste.check(focused: mail)
        let second = paste.start(in: mail)
        #expect(!paste.goesToNextField(second))
        paste.finish(first, "First")
        paste.finish(second, "Second")
        #expect(paste.check(focused: mail) == [.paste("Second")])
        #expect(paste.check(focused: chat) == [.paste("First")])
        #expect(!paste.isActive)
    }

    @Test func aDictationInATakenFieldGoesToTheNextFieldFocused() {
        var paste = ReturnPaste<Field>()
        let first = paste.start(in: chat)
        let second = paste.start(in: chat)
        #expect(paste.goesToNextField(second))
        #expect(paste.check(focused: chat) == [])
        #expect(paste.check(focused: mail) == [.leftField(first, chat)])
        paste.finish(second, "Second")
        #expect(paste.check(focused: mail) == [.paste("Second")])
        paste.finish(first, "First")
        #expect(paste.check(focused: chat) == [.paste("First")])
    }

    @Test func aDictationForTheNextFieldStaysThereOnceBound() {
        var paste = ReturnPaste<Field>()
        _ = paste.start(in: chat)
        let second = paste.start(in: chat)
        _ = paste.check(focused: mail)
        // Back in the first field before the result is ready: it waits for the one it went to.
        #expect(paste.check(focused: chat) == [.leftField(second, mail)])
        paste.finish(second, "Second")
        #expect(paste.check(focused: chat) == [])
        #expect(paste.check(focused: mail) == [.paste("Second")])
    }

    @Test func aDictationForTheNextFieldIsCopiedWhenNoneCameBeforeItWasDone() {
        var paste = ReturnPaste<Field>()
        _ = paste.start(in: chat)
        let second = paste.start(in: chat)
        // Leaving for no text field binds it to nothing.
        #expect(paste.check(focused: nil).count == 1)
        paste.finish(second, "Second")
        #expect(paste.check(focused: chat) == [.copy("Second")])
        #expect(paste.isActive)
    }

    @Test func aFieldIsFreeAgainOnceItsDictationIsPasted() {
        var paste = ReturnPaste<Field>()
        let first = paste.start(in: chat)
        paste.finish(first, "First")
        _ = paste.check(focused: chat)
        #expect(!paste.goesToNextField(paste.start(in: chat)))
    }

    @Test func aFailedDictationWaitsForNothing() {
        var paste = ReturnPaste<Field>()
        let ticket = paste.start(in: chat)
        paste.fail(ticket)
        #expect(!paste.isActive)
        paste.finish(ticket, "Late")
        #expect(paste.check(focused: chat) == [])
        #expect(!paste.goesToNextField(paste.start(in: chat)))
    }
}
