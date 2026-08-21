; Inno Setup script for the FlowCraft Whiteboard Windows installer.
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
#define MyAppURL "https://github.com/alisheraxmedov/flowcraft"

[Setup]
AppId={{6E9F2C2C-9C4C-4B7C-9E6C-4C6E7C9E2C7A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=FlowCraft-Windows-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
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
