# On-device tests

These run **on a real device or desktop**, not on the host's Dart VM.

Almost everything in this app is tested in `test/`, which is faster and needs no
hardware. One thing cannot be: on Android, iOS and macOS the app links the
FFmpeg libraries into itself, and those native archives are downloaded at build
time. "The APK built" is not evidence that they work — a wrong architecture or a
missing symbol fails at the first real call, on the device, in front of the user.
That is what lives here.

## Running them

```bash
flutter devices
flutter test integration_test/media_toolkit_test.dart -d <device id>
```

There is no `flutter drive` setup and no screenshot harness. These are plain
tests that happen to execute on the device.

## What is here

| File | Answers |
|---|---|
| `media_toolkit_test.dart` | Do the linked-in FFmpeg libraries load, probe, convert, split and cancel on this device? |
| `local_asr_test.dart` | Does the whisper.cpp engine built into this app load, pass its check, transcribe and cancel on this device? It fetches the tiny model (75 MiB) once. |

Its assertions deliberately mirror `test/media_toolkit_live_test.dart`, which
covers the external-executable backend on Windows. The two backends are held to
the same behaviour, including the byte budget the chunk planner depends on: a
window planned on one platform and cut on another has to come out the same size.

## What does not belong here

Layout, merging, planning, parsing and every other rule are pure functions or
widget tests, and they belong in `test/` where they run in milliseconds. Add a
test here only when the question is genuinely "does this work on the device".
