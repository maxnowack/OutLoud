# 0025 – macOS pauses with MediaRemote's pause command and plays on with the media key only after the apps it heard fell silent

- Status: accepted
- Date: 2026-10-28

## Context

ADR 0024 paused other audio on the Mac by posting the play/pause media key when the default
output device was running. The user found that it started the Music app with nothing playing. A
sample of four minutes on the user's Mac showed the device running for the system sounds
(`systemsoundserverd`, 2–3 s each) and for the browser, which held the output for exactly 10 s
after a sound and for minutes with a page open — the device running says that a process uses
it, not that a player plays. The media key is a toggle: with no player to pause, macOS starts
the last one, and a paused tab would play.

Ghost Pepper, another dictation app the user uses, sends the pause command of the private
MediaRemote framework, which only pauses and does nothing with nothing playing; the user
confirmed that it works on their Mac. Since macOS 15.4, MediaRemote no longer tells unentitled
apps what plays, but it still takes their commands. Ghost Pepper does not play on afterwards,
because the play command starts Music as well.

A first build that judged a pause by an app's output stopping did not play the browser on: the
browser kept its output running after the pause, with silence in it. Asked from Outloud,
MediaRemote's `MRMediaRemoteGetNowPlayingApplicationIsPlaying` said "not playing" throughout
while music played in the browser — the read is closed, as ADR 0024 said.

Rejected alternatives:

- Deciding by the output's level whether to pause: a call or any other sound is as loud as
  music (the user's objection). Here the level only tells whether the pause took.
- Judging the pause by the output stopping: a browser keeps it running, silent, for seconds.
- Not playing on, as Ghost Pepper: the user would press play after every dictation.
- MediaRemote's play command to play on: it starts Music when the pause paused nothing, as the
  media key does.

## Decision

On macOS, when a recording starts and a process of an app — one whose executable lies inside
an app or an XPC service, as a browser's audio helper does, not Outloud and not a daemon such as
the system sounds' in `/usr/sbin` — puts out sound (Core Audio's per-process
`kAudioProcessPropertyIsRunningOutput`), Outloud listens to those processes through a private
Core Audio process tap that leaves them audible, for up to 0.3 s. If they sound — a peak of
-50 dB or more —, it sends MediaRemote's pause command, loaded at run time. If they then fall
silent for 0.2 s within a second (`PauseCheck`), the pause took, and the play/pause media key
plays them on once the recording ends. If they still sound — a call, a video that does not take
the command —, nothing plays on, and the overlay says that something plays in the background,
which the microphone may pick up. The tap needs the user's permission to record system audio,
which macOS asks for at the first tap; without it, Outloud sends the pause command but does not
play on, and the settings say what is missing. macOS offers no public way to ask for that
permission's state; Outloud asks TCC's private `TCCAccessPreflight`. Without MediaRemote, Outloud
pauses nothing; it never falls back to the toggle. The setting and the Accessibility access the
key needs stay as in ADR 0024. This supersedes ADR 0024's decision for macOS; its decision for
iOS stands.

## Consequences

- Nothing starts with nothing playing: the pause command does nothing then, and the key is
  pressed only after the apps Outloud heard fell silent.
- A second app that sounds on, a call beside the music, keeps the music paused after the
  dictation; the overlay shows the hint.
- An app sound that ends within the second after the pause command while nothing else plays —
  a notification — can still make the key start the last player.
- The tap delays the pause command by the tap's first audio, a few hundredths of a second.
- MediaRemote and TCC's preflight are private: a later macOS may close them, and then nothing
  pauses, or the settings miss the note. The app is not in the Mac App Store (ADR 0009), whose
  review would refuse them.
