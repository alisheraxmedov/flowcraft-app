; Inno Setup script for the FlowCraft Windows installer.
;
; Built by .github/workflows/build-desktop.yml via:
;   iscc /DMyAppVersion=1.2.3 windows\installer\flowcraft.iss
; (run from the repo root, after `flutter build windows --release`)
;
; MyAppVersion defaults to 0.0.0 for local/manual runs where it isn't passed.
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "FlowCraft"
#define MyAppPublisher "FlowCraft"
#define MyAppExeName "flowcraft.exe"
#define MyAppURL "https://github.com/alisheraxmedov/flowcraft-app"

[Setup]
AppId={{6E9F2C2C-9C4C-4B7C-9E6C-4C6E7C9E2C7A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
AppCopyright=Copyright (C) 2026 FlowCraft
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoProductName={#MyAppName}
; Flutter's Windows embedder needs Windows 10 or later, x64 only.
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Unsigned installer: let the user pick a per-user install so no UAC prompt
; with "Unknown publisher" is needed. {autopf} resolves to %LOCALAPPDATA%\Programs
; in that case.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
; The app holds port 5199 while it runs; Restart Manager must close it before
; files are replaced, otherwise an upgrade leaves the old process listening.
CloseApplications=yes
RestartApplications=no
LicenseFile={#SourcePath}..\..\LICENSE
SetupIconFile={#SourcePath}..\runner\resources\app_icon.ico
OutputDir=Output
OutputBaseFilename=FlowCraft-Windows-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Everything `flutter build windows --release` produced. {#SourcePath} is
; this script's own directory (windows\installer\), so this is
; independent of ISCC's invocation working directory.
Source: "{#SourcePath}..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
