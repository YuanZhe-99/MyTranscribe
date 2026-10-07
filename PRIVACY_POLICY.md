# Privacy Policy — MyTranscribe!!!!!

MyTranscribe has no servers. There is no account, no analytics, no crash reporting and no
advertising. Nothing is collected about you.

## Your recordings and transcripts

They are stored on your device, in the app's own folder. Original recordings are uploaded only to the transcription service you select.
Finished transcript text is included in backups, ZIP exports and configured WebDAV sync.
Converted audio sync is opt-in; original recordings are never synced.

## Transcription

To transcribe a recording, the app sends the audio to the transcription service you chose and
configured — for example OpenAI or OpenRouter — using the API key you entered. That service receives
the audio and returns the text. What it does with the audio is governed by that service's own
policy, not this one. If you configure a service running on your own machine, the audio never leaves
it.

With a model on this device, the recording is transcribed on the device and the audio is sent
nowhere.

On an iPhone, iPad or Mac you may choose the system's own speech recognition as the fallback when a
model on this device fails. The app requires it to run on the device, so the audio is not sent to
Apple, and it asks for permission to use speech recognition only after you choose it.

## Downloads

The app downloads something only when you ask it to: a model for transcribing on this device, or
the package that labels speakers, from the address the app shows before it starts; or, on Windows,
the FFmpeg tool it needs. It checks each file it downloads and sends nothing about you or your
recordings with the request. Downloaded models and packages stay on the device; they are not
included in backups, ZIP exports or WebDAV sync. The app contacts no other network service.

## Your API keys

Keys are stored on your device in plain text, alongside the app's other settings. They are sent to
the transcription service they belong to, and to nowhere else.

They are never written into a local backup or a ZIP export. They are only copied to your WebDAV
server when that server is reached over HTTPS, or over a private network address such as your local
network, a Tailscale or EasyTier address, or a machine name on your own network. Over plain HTTP to
a public address, the app syncs your other settings and leaves the keys on the device.

## WebDAV sync

Sync is off until you configure it, and it talks only to the server you entered. It carries your
sources, models, profile and preferences, finished transcript text, and — subject to the rule above — your API keys. Converted audio travels only when you enable audio sync.

## Permissions

The app asks for network access, to reach the transcription service, your WebDAV server, and the
downloads you ask for. It reads a recording only when you pick one. On Apple devices it asks to use
speech recognition only if you choose the system's recognition as the fallback.

## Questions

yuanzhe1999@outlook.com

Before WebDAV network operations, each device must acknowledge the privacy notice.
Existing configurations pause until acknowledgement. Server files are not encrypted by
the app; HTTPS encrypts transport. Public HTTP trusted hosts require a risk warning and
explicit device-local confirmation before keys may travel. Online transcription has a
separate provider/address acknowledgement covering audio, hints, prompts, keywords and
enabled speaker samples.
