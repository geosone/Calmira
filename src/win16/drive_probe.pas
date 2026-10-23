program DriveProbe;

{$APPTYPE GUI}
{$mode objfpc}
{$H-}
{$K+}

uses
  WinTypes, WinProcs, Win31, SysUtils, language_catalog, runtime_paths;

const
  WindowClassName = 'CalmiraDriveProbe';
  WindowTitle = 'Calmira Drive Probe';
  DriveListId = 101;
  RefreshButtonId = 102;
  PollTimerId = 1;
  PollIntervalMs = 2000;

var
  MainWindow: HWND;
  DriveList: HWND;
  RefreshButton: HWND;
  StatusText: HWND;
  LastDriveMask: LongInt;
  LocalTitle: array[0..127] of Char;

procedure InitializeTexts;
var
  Directory: string;
begin
  Directory := RuntimeDirectory;
  InitializeLanguage(Directory + 'LANG', Directory + 'CALMIRA.INI');
  StrPCopy(LocalTitle, LanguageText('DriveProbe', 'Title', WindowTitle));
end;

function BuildDriveMask: LongInt;
var
  Drive: SmallInt;
begin
  BuildDriveMask := 0;
  for Drive := 0 to 25 do
    if GetDriveType(Drive) <> 0 then
      BuildDriveMask := BuildDriveMask or (LongInt(1) shl Drive);
end;

procedure AddDrive(Drive: SmallInt; DriveType: UINT);
var
  Line: array[0..31] of Char;
  Description: string;
begin
  case DriveType of
    DRIVE_REMOVABLE: Description := LanguageText('FileManager', 'Removable', 'Removable');
    DRIVE_FIXED: Description := LanguageText('FileManager', 'Fixed', 'Fixed disk');
    DRIVE_REMOTE: Description := LanguageText('FileManager', 'Network', 'Network');
  else
    Description := LanguageText('FileManager', 'Other', 'Other');
  end;

  FillChar(Line, SizeOf(Line), 0);
  Line[0] := Char(Ord('A') + Drive);
  Line[1] := ':';
  Line[2] := ' ';
  StrPLCopy(@Line[3], Description, 28);
  SendMessage(DriveList, LB_ADDSTRING, 0, LongInt(@Line[0]));
end;

procedure RefreshDrives;
var
  Drive: SmallInt;
  DriveType: UINT;
  Count: SmallInt;
  Status: array[0..47] of Char;
begin
  SendMessage(DriveList, LB_RESETCONTENT, 0, 0);
  Count := 0;
  for Drive := 0 to 25 do
  begin
    DriveType := GetDriveType(Drive);
    if DriveType <> 0 then
    begin
      AddDrive(Drive, DriveType);
      Inc(Count);
    end;
  end;

  FillChar(Status, SizeOf(Status), 0);
  if Count = 1 then
    StrPLCopy(@Status[0], LanguageText('FileManager', 'OneDrive', '1 drive detected'), 47)
  else
    StrPLCopy(@Status[0], LanguageText('FileManager', 'Refreshed', 'Drive list refreshed'), 47);
  SetWindowText(StatusText, @Status[0]);
  LastDriveMask := BuildDriveMask;
end;

procedure ResizeChildren(Window: HWND);
var
  Client: RECT;
  Width: SmallInt;
  Height: SmallInt;
begin
  GetClientRect(Window, Client);
  Width := Client.right - Client.left;
  Height := Client.bottom - Client.top;
  MoveWindow(DriveList, 8, 8, Width - 16, Height - 70, True);
  MoveWindow(RefreshButton, 8, Height - 54, 80, 24, True);
  MoveWindow(StatusText, 98, Height - 50, Width - 106, 20, True);
end;

function MainWndProc(Window: HWND; MessageId: UINT; WParam: WPARAM;
  LParam: LPARAM): LRESULT; export;
var TextBuffer: array[0..127] of Char;
begin
  case MessageId of
    WM_CREATE:
      begin
        DriveList := CreateWindow('LISTBOX', nil,
          WS_CHILD or WS_VISIBLE or WS_BORDER or WS_VSCROLL or LBS_NOTIFY,
          0, 0, 0, 0, Window, HMENU(DriveListId), HInstance, nil);
        StrPCopy(TextBuffer, LanguageText('FileManager', 'Refresh', 'Refresh'));
        RefreshButton := CreateWindow('BUTTON', TextBuffer,
          WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON,
          0, 0, 0, 0, Window, HMENU(RefreshButtonId), HInstance, nil);
        StrPCopy(TextBuffer, LanguageText('FileManager', 'Scanning', 'Scanning drives...'));
        StatusText := CreateWindow('STATIC', TextBuffer,
          WS_CHILD or WS_VISIBLE,
          0, 0, 0, 0, Window, 0, HInstance, nil);
        LastDriveMask := -1;
        RefreshDrives;
        SetTimer(Window, PollTimerId, PollIntervalMs, TFarProc(nil));
        MainWndProc := 0;
        Exit;
      end;
    WM_SIZE:
      begin
        ResizeChildren(Window);
        MainWndProc := 0;
        Exit;
      end;
    WM_COMMAND:
      if WParam = RefreshButtonId then
      begin
        RefreshDrives;
        MainWndProc := 0;
        Exit;
      end;
    WM_TIMER:
      if WParam = PollTimerId then
      begin
        if BuildDriveMask <> LastDriveMask then
          RefreshDrives;
        MainWndProc := 0;
        Exit;
      end;
    WM_DESTROY:
      begin
        KillTimer(Window, PollTimerId);
        PostQuitMessage(0);
        MainWndProc := 0;
        Exit;
      end;
  end;
  MainWndProc := DefWindowProc(Window, MessageId, WParam, LParam);
end;

procedure RegisterMainClass;
var
  WindowClass: WNDCLASS;
begin
  FillChar(WindowClass, SizeOf(WindowClass), 0);
  WindowClass.style := CS_HREDRAW or CS_VREDRAW;
  WindowClass.lpfnWndProc := @MainWndProc;
  WindowClass.hInstance := HInstance;
  WindowClass.hIcon := LoadIcon(0, IDI_APPLICATION);
  WindowClass.hCursor := LoadCursor(0, IDC_ARROW);
  WindowClass.hbrBackground := GetStockObject(WHITE_BRUSH);
  WindowClass.lpszClassName := WindowClassName;
  if RegisterClass(WindowClass) = 0 then
  begin
    MessageBox(0, 'Unable to register the main window class.', WindowTitle,
      MB_OK or MB_ICONHAND);
    Halt(1);
  end;
end;

procedure RunMessageLoop;
var
  MessageRecord: MSG;
begin
  while GetMessage(MessageRecord, 0, 0, 0) do
  begin
    TranslateMessage(MessageRecord);
    DispatchMessage(MessageRecord);
  end;
end;

begin
  InitializeTexts;
  if HPrevInst = 0 then
    RegisterMainClass;
  MainWindow := CreateWindow(WindowClassName, LocalTitle,
    WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 500, 320,
    0, 0, HInstance, nil);
  if MainWindow = 0 then
    Halt(1);
  ShowWindow(MainWindow, CmdShow);
  UpdateWindow(MainWindow);
  RunMessageLoop;
end.
