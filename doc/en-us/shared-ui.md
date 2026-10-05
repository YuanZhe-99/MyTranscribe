# Shared UI foundations

MyApps-UI `v0.1.0` is embedded at `packages/myapps_ui` using relative submodule
URL `../MyApps-UI.git`. Initialize submodules recursively after cloning.

`lib/app/theme.dart` preserves its existing public facade, teal seed and default
Expressive style while delegating to `myapps_ui`. Shared enums retain stored names.
Dynamic-color platform policy remains app-owned.

`lib/shared/utils/adaptive_layout.dart` re-exports common thresholds and
`canSplitLayout`, `useNavigationRail`, `columnCapacity`, `listRowCount` from
`myapps_adaptive`. Job, library, transcript and audio-control sizes remain here.
The legacy content-width prediction is unchanged pending the navigation stage.
Profile, settings, transcript, secrets and audio formats are unaffected.

## Updating

Publish the shared commit and tag to both remotes before an application pointer
update. Pin the tag and run app analysis and all tests. Library docs cover shared
declarations; this app retains its integration and business layout documentation.
