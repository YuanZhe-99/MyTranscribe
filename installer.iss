; Inno Setup script for MyTranscribe!!!!! on Windows.
;
; Build the app first, then compile this:
;   flutter build windows --release
;   iscc installer.iss                    (x64)
;   iscc /DARM64 installer.iss            (ARM64)
;
; AppId is this application's own GUID and must never change: Windows uses it to
; recognise an upgrade, and a new one would install a second copy alongside the
; first rather than replacing it.
;
; The three version fields below are part of the release checklist in AGENTS.md
; and move together with pubspec.yaml's two.

[Setup]
AppId={{3F6C0B7A-9D41-4E52-B18A-7C5E2D904A63}
AppName=MyTranscribe!!!!!
AppVersion=0.1.0
AppPublisher=yuanzhe
DefaultDirName={autopf}\MyTranscribe!!!!!
DefaultGroupName=MyTranscribe!!!!!
UninstallDisplayIcon={app}\my_transcribe.exe
OutputDir=build\installer
#ifdef ARM64
OutputBaseFilename=MyTranscribe_{#SetupSetting("AppVersion")}_arm64_Setup
#else
OutputBaseFilename=MyTranscribe_{#SetupSetting("AppVersion")}_Setup
#endif
VersionInfoVersion=0.1.0.0
VersionInfoCompany=yuanzhe
VersionInfoDescription=MyTranscribe!!!!! Installer
VersionInfoProductName=MyTranscribe!!!!!
VersionInfoProductVersion=0.1.0
Compression=lzma2
SolidCompression=yes
#ifdef ARM64
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
; Installs per-user, so no administrator prompt. The app writes only to the
; user's own documents directory and needs nothing more.
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
#ifdef ARM64
Source: "build\windows\arm64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
#else
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
#endif

[Icons]
Name: "{group}\MyTranscribe!!!!!"; Filename: "{app}\my_transcribe.exe"
Name: "{group}\{cm:UninstallProgram,MyTranscribe!!!!!}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\MyTranscribe!!!!!"; Filename: "{app}\my_transcribe.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\my_transcribe.exe"; Description: "{cm:LaunchProgram,MyTranscribe!!!!!}"; Flags: nowait postinstall skipifsilent
