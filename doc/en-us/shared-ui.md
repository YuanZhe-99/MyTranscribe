# Shared UI foundations

MyApps-UI `v0.1.1` is embedded at `packages/myapps_ui` using relative submodule
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

Profile extraction remains P3; data formats are unchanged.
