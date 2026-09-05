# MyTranscribe!!!!!

[![Build All Platforms](https://github.com/YuanZhe-99/MyTranscribe/actions/workflows/build.yml/badge.svg)](https://github.com/YuanZhe-99/MyTranscribe/actions/workflows/build.yml)

Turn a recording into text, on your phone, tablet or desktop.

MyTranscribe sends audio to a transcription service **you** configure — OpenAI, OpenRouter, or any
OpenAI-compatible endpoint including one running on your own machine — and gives you back a
transcript you can read, correct and export. A recording too large to upload in one piece is split
into overlapping windows with FFmpeg and stitched back together; if a run is interrupted, the next
one picks up where it stopped.

- **Sources and models you control.** Built-in templates for the common services, and room for your
  own endpoint. Each model records its own limits, so the app can work out how to split a recording
  instead of asking you.
- **Speakers.** Where the model can tell people apart, the transcript says who spoke — and you can
  name them, merge them and correct them.
- **Your data stays yours.** Recordings and transcripts never leave the device except to the
  transcription service you chose. There is no account and no analytics.
- **Config that follows you.** Sources, models and preferences sync to your own WebDAV server. API
  keys travel only when the connection is safe: HTTPS, or a private address such as your local
  network, Tailscale or ZeroTier.
- **One layout, every shape.** Phone, tablet, foldable and desktop, following the series' adaptive
  layout rules.

Part of the MyApps series, alongside MyAnime!!!!!, MyDay!!!!!, MyDevice!!!!! and MyNihongo!!!!!,
sharing the `myapps_data` sync and backup engines.

## Status

Version 0.1.0. Everything described above is built and covered by the test suite, which runs with no
API key, no network and no FFmpeg. One path has **not** been exercised against a paid service yet: a
real recording over the upload limit, transcribed end to end. If you try it and it misbehaves, that
is the most likely place.

## Building

```bash
git clone --recurse-submodules https://github.com/YuanZhe-99/MyTranscribe.git
cd MyTranscribe
flutter pub get
flutter gen-l10n
flutter analyze && flutter test
flutter run -d windows           # or -d android, macos, ios
```

Already cloned without `--recurse-submodules`? Run `git submodule update --init` — `myapps_data` is a
path dependency inside a submodule, and `flutter pub get` fails without it.

GitHub Actions builds all five targets on every push, and attaches an APK, an AAB, both Windows
installers, an unsigned IPA and a DMG to the Release for each `v*` tag. See
[`doc/en-us/ci-cd.md`](doc/en-us/ci-cd.md).

Windows and Linux need `ffmpeg` and `ffprobe`; Settings offers to download them on Windows. Android,
iOS and macOS have the libraries built in.

## Documentation

Concept documentation is in [`doc/en-us/`](doc/en-us/) with a Chinese mirror in
[`doc/zh-cn/`](doc/zh-cn/). [`AGENTS.md`](AGENTS.md) is the working guide for agents;
[`PLAN.md`](PLAN.md) is the roadmap.

## Licence

GPL-3.0. See [LICENSE](LICENSE) and [PRIVACY_POLICY.md](PRIVACY_POLICY.md).
