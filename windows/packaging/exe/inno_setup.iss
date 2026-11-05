[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
; GPL-3.0: show the licence before installation and require acknowledgement.
; The file is placed next to the executable by windows/CMakeLists.txt, so it is
; present in {{SOURCE_DIR}} when ISCC compiles this script.
LicenseFile={{SOURCE_DIR}}\LICENSE
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
UninstallDisplayIcon={app}\{{EXECUTABLE_NAME}}
WizardStyle=modern
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCH}}
ArchitecturesInstallIn64BitMode={{ARCH}}
CloseApplications=yes
; P10-P0-A - the helper is NOT in this filter. Restart Manager would otherwise
; offer to close a running LocalSystem helper just because this package happens
; to carry a file with the same name, and nothing in this installer needs the
; helper to be closed: it lives in the protected directory, which {app} copy
; operations never touch.
CloseApplicationsFilter={{EXECUTABLE_NAME}},{{CORE_EXECUTABLE_NAME}}
SetupLogging=yes

[Code]
var
  ShouldCleanUserData: Boolean;

function IsProcessRunning(ProcessName: String): Boolean;
var
  ResultCode: Integer;
begin
  Exec('cmd.exe', '/c tasklist /fi "imagename eq ' + ProcessName + '" 2>nul | find /i "' + ProcessName + '" >nul', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := (ResultCode = 0);
end;

// P10-P0-A - what does the helper service look like right now?
//
// This installer no longer creates, deletes, stops or re-points the helper
// service at all (see the removed RegisterHelperService / UnregisterHelperService
// below). What it still needs is the ability to tell "there is no service yet"
// apart from "there is one, and it is not mine" - because the second case must
// stop the install rather than quietly lay down a second, older helper next to
// a protected one.
//
// Four states, not two, because "the key exists but ImagePath is unreadable" is
// not the same as "no service": treating it as "no service" is what would let a
// re-install proceed against an unknown deployment.
const
  HS_MISSING = 0;
  HS_LOCAL = 1;
  HS_MANAGED = 2;
  HS_UNKNOWN = 3;

function StripQuotes(const S: String): String;
begin
  Result := S;
  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function HelperServiceImagePath(): String;
var
  Value: String;
begin
  Result := '';
  if RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Services\{{HELPER_SERVICE_NAME}}', 'ImagePath', Value) then
    Result := StripQuotes(Value);
end;

function HelperServiceState(): Integer;
var
  ImagePath: String;
  AppDir: String;
  ServiceKey: String;
begin
  ServiceKey := 'SYSTEM\CurrentControlSet\Services\{{HELPER_SERVICE_NAME}}';

  if not RegKeyExists(HKLM, ServiceKey) then
  begin
    Result := HS_MISSING;
    Exit;
  end;

  if not RegQueryStringValue(HKLM, ServiceKey, 'ImagePath', ImagePath) then
  begin
    Result := HS_UNKNOWN;
    Exit;
  end;

  ImagePath := StripQuotes(ImagePath);
  if ImagePath = '' then
  begin
    Result := HS_UNKNOWN;
    Exit;
  end;

  AppDir := ExpandConstant('{app}');
  if (AppDir = '') or (Pos('{', AppDir) > 0) then
  begin
    Result := HS_UNKNOWN;
    Exit;
  end;

  if Pos(Lowercase(AppDir + '\'), Lowercase(ImagePath)) = 1 then
    Result := HS_LOCAL
  else
    Result := HS_MANAGED;
end;

function IsManagedHelperDeployment(): Boolean;
begin
  Result := HelperServiceState() = HS_MANAGED;
end;

procedure ForceKillProcesses(IsUninstall: Boolean);
var
  ResultCode: Integer;
  WaitCount: Integer;
begin
  // P10-P0-A - the helper is deliberately absent from this procedure.
  //
  // It used to run "sc stop" and then "taskkill /f" on the helper before
  // copying files. That is what produced the observed 7034 events with exit
  // code 1067, and it was never necessary: this installer no longer owns the
  // helper service, so there is nothing here for it to free up. The service is
  // created by the app, in the protected directory, on first launch.
  Log('P10-P0-A: helper service is not touched by this installer');

  { Try to elegantly exit the main app using --exit parameter.
    P10-P0-A - only when this machine has no protected deployment. An older
    client in the install directory would answer --exit by stopping the shared
    helper, so the call is skipped rather than trusted. HS_MANAGED never reaches
    here anyway (InitializeSetup aborts), but the guard is kept explicit. }
  if (HelperServiceState() <> HS_MANAGED) and
     FileExists(ExpandConstant('{app}\{{EXECUTABLE_NAME}}')) and
     IsProcessRunning('{{EXECUTABLE_NAME}}') then
  begin
    if IsUninstall then
      UninstallProgressForm.StatusLabel.Caption := CustomMessage('ShuttingDownRunningApp')
    else
      WizardForm.StatusLabel.Caption := CustomMessage('ShuttingDownRunningApp');
    Exec(ExpandConstant('{app}\{{EXECUTABLE_NAME}}'), '--exit', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    { Wait up to 4 seconds for the main app and core to exit }
    WaitCount := 0;
    while (WaitCount < 8) and (IsProcessRunning('{{EXECUTABLE_NAME}}') or IsProcessRunning('{{CORE_EXECUTABLE_NAME}}')) do
    begin
      Sleep(500);
      WaitCount := WaitCount + 1;
    end;
  end;

  // P10-P0-A - the blanket "taskkill /f /im" fallbacks were removed.
  //
  // They matched on image name alone, so an instance installed somewhere else -
  // a second copy, a test build, the user's own portable copy - was killed by
  // name. Nothing here can prove which process belongs to this installation, and
  // the rule is: when ownership cannot be established, do not kill. A file that
  // is still locked now surfaces as a Restart Manager prompt, which is a
  // failure the user can act on, instead of a silent kill of someone else's app.
end;

procedure CleanWintunDevices;
var
  ResultCode: Integer;
  PowerShellScript: String;
  TempScriptPath: String;
begin
  PowerShellScript := 
    '$ErrorActionPreference = ''SilentlyContinue'';' + #13#10 +
    'Write-Host "Cleaning Fluxora network adapters...";' + #13#10 +
    { P10-P0-A - ownership by exact identity, not by name substring.
      A "Fluxora"-named adapter is not proof that Fluxora created it, and a
      wintun adapter belongs to us only when it carries both the exact device
      name we set and the wintun driver description. Anything that does not
      match both is left alone. }
    '$adapters = Get-NetAdapter | Where-Object {' + #13#10 +
    '  $_.Name -eq "Fluxora" -and' + #13#10 +
    '  $_.InterfaceDescription -eq "Wintun Userspace Tunnel"' + #13#10 +
    '};' + #13#10 +
    'if ($adapters) {' + #13#10 +
    '  foreach ($adapter in $adapters) {' + #13#10 +
    '    Write-Host "Removing adapter: $($adapter.Name) - $($adapter.InterfaceDescription)";' + #13#10 +
    '    try {' + #13#10 +
    '      $adapter | Disable-NetAdapter -Confirm:$false -ErrorAction Stop;' + #13#10 +
    '      Start-Sleep -Milliseconds 500;' + #13#10 +
    '      $adapter | Remove-NetAdapter -Confirm:$false -ErrorAction Stop;' + #13#10 +
    '      Write-Host "Successfully removed: $($adapter.Name)";' + #13#10 +
    '    } catch {' + #13#10 +
    '      Write-Host "Failed to remove $($adapter.Name): $_";' + #13#10 +
    '    }' + #13#10 +
    '  }' + #13#10 +
    '} else {' + #13#10 +
    '  Write-Host "No old adapters found.";' + #13#10 +
    '}' + #13#10 +
    'Write-Host "Cleanup completed.";';
  
  TempScriptPath := ExpandConstant('{tmp}\clean_wintun.ps1');
  SaveStringToFile(TempScriptPath, PowerShellScript, False);

  Exec('powershell.exe', 
    '-NoProfile -ExecutionPolicy Bypass -File "' + TempScriptPath + '"', 
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  
  DeleteFile(TempScriptPath);
end;

// P10-P0-A - RegisterHelperService and UnregisterHelperService were removed.
//
// They ran "sc stop" -> "sc delete" -> "sc create binPath={app}\..." -> "sc
// start" on every install, and "sc stop" -> "sc delete" on every uninstall.
// Three separate problems, none of them fixable by adding a path check in front:
//
//   1. The created service ran a LocalSystem binary out of a user-writable
//      directory - the exact privilege-escalation shape SEC-P0-01 removed.
//   2. "sc delete" + "sc create" dropped the Environment block, so the helper
//      lost HELPER_AUTH_KEY and every IPC call after an upgrade failed.
//   3. It replaced a healthy, protected deployment with an older one.
//
// The service is now created in exactly one place: the app, on first launch,
// through deployThenConfigure, which verifies the helper closure against the
// asset manifest and deploys it into the protected directory before any SCM
// call. The installer's only job is to lay down files.

procedure UnregisterTaskScheduler;
var
  ResultCode: Integer;
  TaskNames: TArrayOfString;
  i: Integer;
begin
  TaskNames := ['{{TASK_NAME}}'];
  
  for i := 0 to GetArrayLength(TaskNames)-1 do
  begin
    Exec('schtasks', '/Delete /TN ' + TaskNames[i] + ' /F', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure CleanRegistry;
var
  RegistryKeys: TArrayOfString;
  i: Integer;
begin
  SetArrayLength(RegistryKeys, 2);
  RegistryKeys[0] := 'Software\Fluxora';
  RegistryKeys[1] := 'Software\io.fluxora.app';
  
  for i := 0 to GetArrayLength(RegistryKeys)-1 do
  begin
    RegDeleteKeyIncludingSubkeys(HKCU, RegistryKeys[i]);
  end;
end;

procedure CleanUserData;
var
  UserDataPaths: TArrayOfString;
  i: Integer;
  AppDataPath: String;
begin
  AppDataPath := ExpandConstant('{userappdata}');
  
  SetArrayLength(UserDataPaths, 2);
  UserDataPaths[0] := AppDataPath + '\Fluxora';
  UserDataPaths[1] := AppDataPath + '\io.fluxora.app';
  
  for i := 0 to GetArrayLength(UserDataPaths)-1 do
  begin
    if DirExists(UserDataPaths[i]) then
    begin
      DelTree(UserDataPaths[i], True, True, True);
    end;
  end;
end;

function InitializeSetup(): Boolean;
var
  State: Integer;
  ImagePath: String;
begin
  Result := True;
  State := HelperServiceState();

  if State = HS_MISSING then
  begin
    // First install. Nothing to protect, and the app creates the service itself
    // in the protected directory once it has verified the asset manifest.
    Log('P10-P0-A: no helper service yet; the app will create it');
    Exit;
  end;

  if State = HS_LOCAL then
  begin
    // A LocalSystem service whose binary sits in the install directory is the
    // pre-SEC-P0-01 layout, and it cannot be migrated from here: this installer
    // is forbidden from touching the service, and simply overwriting the binary
    // underneath it would leave a privileged service running a file any local
    // user can replace. Refusing is the only answer that does not make it worse.
    ImagePath := HelperServiceImagePath();
    MsgBox(CustomMessage('LegacyHelperDetected') + #13#10#13#10 + ImagePath,
      mbError, MB_OK);
    Log('P10-P0-A: refusing to install; legacy helper at ' + ImagePath);
    Result := False;
    Exit;
  end;

  if State = HS_MANAGED then
  begin
    ImagePath := HelperServiceImagePath();
    MsgBox(CustomMessage('ManagedHelperDetected') + #13#10#13#10 + ImagePath,
      mbError, MB_OK);
    Log('P10-P0-A: refusing to install; managed helper at ' + ImagePath);
    Result := False;
    Exit;
  end;

  // HS_UNKNOWN: the key exists but ImagePath could not be read or is empty.
  // Guessing "no service" here is what would let an install proceed against an
  // unknown deployment, so it fails closed with its own message.
  MsgBox(CustomMessage('HelperStateUnknown'), mbError, MB_OK);
  Log('P10-P0-A: refusing to install; helper service state is unreadable');
  Result := False;
end;

function InitializeUninstall(): Boolean;
var
  Response: Integer;
begin
  Response := MsgBox(CustomMessage('RemoveUserDataPrompt'), mbConfirmation, MB_YESNOCANCEL);
  
  if Response = IDCANCEL then
  begin
    Result := False;
  end
  else
  begin
    ShouldCleanUserData := (Response = IDYES);
    Result := True;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    { Let Inno Setup try CloseApplications first; force-kill any leftovers before files are copied. }
    ForceKillProcesses(False);
  end;

  // P10-P0-A - no ssPostInstall service registration. See the note where
  // RegisterHelperService used to be.
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    ForceKillProcesses(True);
    CleanWintunDevices;
  end;
  
  if CurUninstallStep = usPostUninstall then
  begin
    // P10-P0-A - the helper service is not unregistered here. Removing it would
    // delete a deployment this build does not own, and the app re-creates it in
    // the protected directory anyway.
    UnregisterTaskScheduler;
    
    if ShouldCleanUserData then
    begin
      CleanUserData;
      CleanRegistry;
    end;
  end;
end;

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
{% if LOCALES %}
{% for locale in LOCALES %}
{% if locale.lang == 'zh' %}
Name: "chineseSimplified"; MessagesFile: {% if locale.file %}{{ locale.file }}{% else %}"compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% endif %}
{% endfor %}
{% endif %}

[CustomMessages]
english.ShuttingDownRunningApp=Shutting down running {{DISPLAY_NAME}}...
english.ManagedHelperDetected=Fluxora is already installed with a protected helper service, so this package cannot upgrade it safely. Please update from inside the running application instead.%n%nExisting service binary:
english.HelperStateUnknown=A Fluxora helper service exists but its configuration could not be read, so this installer cannot tell whether replacing it would be safe. Nothing was changed. Please update from inside the running application instead.
english.LegacyHelperDetected=An older Fluxora helper service is registered against a user-writable directory. That layout is unsafe and this installer will not overwrite it.%n%nNothing was changed. To repair it, run this from an administrator prompt, then install again:%n%n    sc stop {{HELPER_SERVICE_NAME}}%n    sc delete {{HELPER_SERVICE_NAME}}%n%nExisting service binary:
english.RemoveUserDataPrompt=Do you want to remove all user data?%n%nThis will remove:%n• Configuration files%n• Profiles and subscriptions%n• Settings and preferences%n• Registry entries%n%nThis action cannot be undone.
{% if LOCALES %}
{% for locale in LOCALES %}
{% if locale.lang == 'zh' %}
chineseSimplified.ShuttingDownRunningApp=正在关闭运行中的 {{DISPLAY_NAME}}...
chineseSimplified.ManagedHelperDetected=本机已存在受保护的 Fluxora 助手服务，此安装包无法安全升级该部署。请在正在运行的应用内完成更新。%n%n现有服务路径：
chineseSimplified.HelperStateUnknown=检测到 Fluxora 助手服务，但无法读取其配置，因此无法判断替换是否安全。未做任何更改。请在正在运行的应用内完成更新。
chineseSimplified.LegacyHelperDetected=检测到旧版 Fluxora 助手服务，其程序位于用户可写目录，该布局不安全，本安装包不会覆盖它。%n%n未做任何更改。如需修复，请以管理员身份运行以下命令后重新安装：%n%n    sc stop {{HELPER_SERVICE_NAME}}%n    sc delete {{HELPER_SERVICE_NAME}}%n%n现有服务路径：
chineseSimplified.RemoveUserDataPrompt=是否要删除所有用户数据？%n%n这将删除：%n• 配置文件%n• 代理配置与订阅%n• 设置和偏好%n• 注册表记录%n%n此操作无法撤销。
{% endif %}
{% endfor %}
{% endif %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: {% if PRIVILEGES_REQUIRED == 'admin' %}runascurrentuser{% endif %} nowait postinstall skipifsilent