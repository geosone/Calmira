{ Shared integration flow; build separate image and native-button profiles
  rather than exceeding the Win16 automatic-data segment. }
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Graphics, Controls,
  StdCtrls,
{$IFNDEF PROGRESS_BUTTON}
  ExtCtrls,
{$ENDIF}
  BarGauge, native_form, native_loop;
type
  TProgressProbe = class(TNativeForm)
  private
    procedure Timer(var M: TMessage); message WM_TIMER;
    procedure QueryClose(Sender: TObject; var CanClose: Boolean);
    procedure Stopped(Sender: TObject);
{$IFDEF PROGRESS_BUTTON}
    procedure CancelClicked(Sender: TObject);
{$ENDIF}
{$IFNDEF PROGRESS_BUTTON}
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
{$ENDIF}
  public
    Status: TLabel;
{$IFNDEF PROGRESS_BUTTON}
    Image: TImage;
{$ENDIF}
    Gauge: TWin95Gauge;
{$IFDEF PROGRESS_BUTTON}
    CancelButton: TButton;
{$ENDIF}
    Steps, CancelAt: Integer;
    Running, Cancelled, Completed, EscapeCancel, PixelsOkay: Boolean;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start(CancelStep: Integer; ViaEscape: Boolean);
  end;
var Form: TProgressProbe; Loop: TNativeMessageLoop; Failed: Boolean;
  OldWindow: HWND; Phase: Integer;
procedure LogLine(const Text: string);
var F: HFILE; Buffer: array[0..255] of Char; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Buffer, Line);
  _lwrite(F, @Buffer, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
constructor TProgressProbe.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Progress integration'; SetBounds(20, 20, 270, 175);
  Status := TLabel.Create(Self); Status.Parent := Self;
  Status.SetBounds(54, 12, 180, 22); Status.Color := Color; Status.Font.Color := clBlue;
{$IFNDEF PROGRESS_BUTTON}
  Image := TImage.Create(Self); Image.Parent := Self;
  Image.SetBounds(10, 8, 32, 32); Image.Color := Color;
  Image.Picture.Icon.LoadFromResource(0, IDI_APPLICATION);
{$ELSE}
  Status.SetBounds(10, 12, 220, 22);
{$ENDIF}
  Gauge := TWin95Gauge.Create(Self); Gauge.Parent := Self;
  Gauge.SetBounds(10, 55, 203, 23); Gauge.ForeColor := clLime; Gauge.BackColor := clBlue;
  Gauge.MaxValue := 20;
{$IFDEF PROGRESS_BUTTON}
  CancelButton := TButton.Create(Self); CancelButton.Caption := 'Cancel';
  CancelButton.Cancel := True;
  CancelButton.SetBounds(150, 88, 75, 23); CancelButton.OnClick := CancelClicked;
  CancelButton.Parent := Self;
{$ENDIF}
  OnCloseQuery := QueryClose; OnHide := Stopped;
end;
destructor TProgressProbe.Destroy;
begin
  if Handle <> 0 then KillTimer(Handle, 11);
  inherited Destroy;
end;
procedure TProgressProbe.Start(CancelStep: Integer; ViaEscape: Boolean);
begin
  Steps := 0; CancelAt := CancelStep; EscapeCancel := ViaEscape;
  Cancelled := False; Completed := False; PixelsOkay := True; Running := True;
  Status.Caption := 'Starting'; Gauge.Progress := 0;
  Show; Status.Show; Gauge.Show;
{$IFDEF PROGRESS_BUTTON}
  SetActiveWindow(Handle); CancelButton.SetFocus;
{$ENDIF}
{$IFNDEF PROGRESS_BUTTON}
  Image.Show;
{$ENDIF}
  Update;
  if SetTimer(Handle, 11, 20, nil) = 0 then raise Exception.Create('Timer start failed');
end;
procedure TProgressProbe.QueryClose(Sender: TObject; var CanClose: Boolean);
begin
  if not Completed then Cancelled := True;
  CanClose := True;
end;
procedure TProgressProbe.Stopped(Sender: TObject);
begin
  if not Running then Exit;
  Running := False; KillTimer(Handle, 11); PostQuitMessage(0);
end;
{$IFDEF PROGRESS_BUTTON}
procedure TProgressProbe.CancelClicked(Sender: TObject);
begin Close; end;
{$ENDIF}
{$IFNDEF PROGRESS_BUTTON}
procedure TProgressProbe.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then begin Key := 0; Close; end
  else inherited KeyDown(Key, Shift);
end;
{$ENDIF}
procedure TProgressProbe.Timer(var M: TMessage);
var DC: HDC;
begin
  if (M.WParam <> 11) or not Running then Exit;
  Inc(Steps); Gauge.AddProgress(1); Status.Caption := 'Step ' + IntToStr(Steps);
  Gauge.Update; Status.Update;
{$IFNDEF PROGRESS_BUTTON}
  Image.Update;
{$ENDIF}
  DC := GetDC(Handle);
  if DC = 0 then raise Exception.Create('Missing progress DC');
  try
    PixelsOkay := PixelsOkay and (GetPixel(DC, Gauge.Left + 4, Gauge.Top + 4) = DWORD(clLime));
  finally ReleaseDC(Handle, DC); end;
  if (CancelAt <> 0) and (Steps = CancelAt) then
  begin
    if EscapeCancel then
    begin
      if not PostMessage(
{$IFDEF PROGRESS_BUTTON}
        CancelButton.Handle,
{$ELSE}
        Handle,
{$ENDIF}
        WM_KEYDOWN, VK_ESCAPE, 1) then
        raise Exception.Create('Cannot post Escape');
    end
    else
    begin
{$IFDEF PROGRESS_BUTTON}
      if not PostMessage(CancelButton.Handle, WM_LBUTTONDOWN, MK_LBUTTON, $00080008) or
        not PostMessage(CancelButton.Handle, WM_LBUTTONUP, 0, $00080008) then
        raise Exception.Create('Cannot post Cancel');
{$ELSE}
      if not PostMessage(Handle, WM_CLOSE, 0, 0) then raise Exception.Create('Cannot post Close');
{$ENDIF}
    end;
  end;
  if Steps = Gauge.MaxValue then
  begin Completed := True; Status.Caption := 'Completed'; Status.Update; Hide; end;
end;
begin
  LogLine('STEP integrated progress UI');
  try
    Form := TProgressProbe.Create(nil);
    Form.Start(5, False); Loop := TNativeMessageLoop.Create;
    Loop.OnMessage := Form.ProcessDialogMessage;
    Check(Loop.Run = 0, 'timer-driven loop exits on cancel');
    Check(Form.Cancelled and not Form.Completed and (Form.Steps = 5) and not Form.Visible and
      (Form.Gauge.Progress = 5),
{$IFDEF PROGRESS_BUTTON}
      'native Cancel stops progress at step 5');
{$ELSE}
      'WM_CLOSE cancels progress at step 5');
{$ENDIF}
    Check(Form.PixelsOkay and (Form.CallbackErrors = 0), 'gauge pixels match timer steps');
    OldWindow := Form.Handle; Form.DestroyHandle;
    Check((Form.Handle = 0) and not IsWindow(OldWindow) and (Form.Status.Parent = Form) and
{$IFDEF PROGRESS_BUTTON}
      (Form.CancelButton.Parent = Form) and (Form.CancelButton.Handle = 0) and
{$ELSE}
      (Form.Image.Parent = Form) and
{$ENDIF}
      (Form.Gauge.Parent = Form),
      'frame destruction preserves owned model');
    Loop.Free; Loop := nil; Form.Start(0, False); Loop := TNativeMessageLoop.Create;
    Loop.OnMessage := Form.ProcessDialogMessage;
    Check((Loop.Run = 0) and Form.Completed and not Form.Cancelled and (Form.Gauge.Progress = 20) and
      (Form.Status.Caption = 'Completed'), 'recreated progress completes 20 steps');
    Check(
{$IFNDEF PROGRESS_BUTTON}
      not Form.Image.Picture.Empty and
{$ENDIF}
      Form.PixelsOkay and (Form.CallbackErrors = 0),
{$IFDEF PROGRESS_BUTTON}
      'recreated button and graphics remain usable');
{$ELSE}
      'recreated icon and graphics remain usable');
{$ENDIF}
    Loop.Free; Loop := nil; Form.Start(3, True); Loop := TNativeMessageLoop.Create;
    Loop.OnMessage := Form.ProcessDialogMessage;
    Check((Loop.Run = 0) and Form.Cancelled and not Form.Completed and (Form.Steps = 3),
      'Escape cancels progress at step 3');
    Check(
{$IFDEF PROGRESS_BUTTON}
      (GetWindow(Form.Handle, GW_CHILD) = Form.CancelButton.Handle) and
      (GetWindow(Form.CancelButton.Handle, GW_HWNDNEXT) = 0) and
{$ELSE}
      (GetWindow(Form.Handle, GW_CHILD) = 0) and (TGraphicControl(Form.Image).Canvas.Handle = 0) and
{$ENDIF}
      (Form.CallbackErrors = 0) and (Form.Status.Canvas.Handle = 0) and
      (Form.Gauge.Canvas.Handle = 0), 'child HWNDs and borrowed paint DCs match profile');
    for Phase := 1 to 20 do
    begin Form.Show; Form.Update; Form.Hide; end;
    Check(Form.CallbackErrors = 0, 'integrated show/update/hide remains usable');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Loop <> nil then Loop.OnMessage := nil;
  Form.Free; Loop.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
