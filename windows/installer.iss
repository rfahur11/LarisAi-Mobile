; Inno Setup Script for LarisAI Kasir Mobile & Desktop POS
; Generates a single standalone LarisAI_Kasir_Setup.exe installer

#define MyAppName "LarisAI Kasir"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "LarisAI - Weboz Ecosystem"
#define MyAppURL "https://weboz.my.id/larisai"
#define MyAppExeName "larisai_mobile.exe"
#define SourceBuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{D8F9A2B3-7E1C-4D5E-9F8A-3C2B1A0F9E8D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\build\dist
OutputBaseFilename=LarisAI_Kasir_Windows_Setup_v1.0.0
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceBuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
