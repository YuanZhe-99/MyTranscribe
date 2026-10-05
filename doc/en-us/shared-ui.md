# Shared UI foundations

MyApps-UI v0.1.7 keeps compact settings choices horizontal using centered wrapped
labels; vertical fallback is reserved for labels exceeding two lines.

DATA v1.0.5 owns WebDAV connection and operation controls. Endpoint security and
audio-sync settings remain application-owned and use injected content/callbacks.

MyApps-UI v0.1.6 owns appearance/navigation row layout and full-width choices.
MyApps-DATA v1.0.4 owns data actions and backup preferences. Transcription,
provider, secret and local-model settings remain application-owned.

## P5 region policies and attribution

Settings consumes MyApps-UI v0.1.5 MyAppsPaneBody with its existing gate and width
policy. Separator fallback reports the actual mode to the app's routing cache.
AppLicensePage names all three consumed packages, source URL and GNU GPL v3.
Job, library and transcript page designs remain app-owned.

## Settings and common catalogs

The app pins MyApps-UI v0.1.4. Shared settings sections and segmented controls
retain provider callbacks, storage and routes. Common appearance/navigation ARB
values are library-owned and checked by shared_l10n_test. Transcription-specific
text and runtime delegates stay here. The extraction is complete; library concept
docs replace the completed roadmap.

MyApps-UI `v0.1.2` is embedded at `packages/myapps_ui` using relative submodule
URL `../MyApps-UI.git`. Initialize submodules recursively after cloning.

`lib/app/theme.dart` preserves its existing public facade, teal seed and default
Expressive style while delegating to `myapps_ui`. Shared enums retain stored names.
Dynamic-color platform policy remains app-owned.

`lib/shared/utils/adaptive_layout.dart` re-exports common thresholds and
`canSplitLayout`, `useNavigationRail`, `columnCapacity`, `listRowCount` from
`myapps_adaptive`. Job, library, transcript and audio-control sizes remain here.
Profile, settings, transcript, secrets and audio formats are unaffected.

## Updating

Publish the shared commit and tag to both remotes before an application pointer
update. Pin the tag and run app analysis and all tests. Library docs cover shared
declarations; this app retains its integration and business layout documentation.

## P2 navigation and actual space

The application now delegates navigation rendering to `MyAppsNavigationShell`.
App-side shells retain routes, destination filtering, selection persistence and reminder
callbacks. Each page passes `context` to its width and bottom-inset helpers: measured
shell content width is used once, and full-window routes subtract no rail. The legacy
context-free helper remains for callers that explicitly request the old calculation.
The stable content slot preserves page state across resize, style and rail-side changes.
MyVidComp retains classic navigation, extended rails and review badges.

Profile extraction is complete in P3; data formats are unchanged.

## P3 profile and avatar

The five profile-bearing apps consume `myapps_profile`. Profile model, merge,
image processing, repository, avatar rendering, editor and header view are shared.
App ProfileStore supplies active storage root, atomic writer and sync notification;
image-service resolution/deletion remains injected. Existing imports are re-export
shims. App Riverpod providers, data-module registry, picker and localized edit dialog
remain adapters. JSON, module order, image naming and field-merge behavior are unchanged.
