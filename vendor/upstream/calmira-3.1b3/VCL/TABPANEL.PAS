{*********************************************************}
{                                                         }
{    Calmira Visual Component Library 3.1                 }
{    by Li-Hsin Huang,                                    }
{    released into the public domain july 2000            }
{                                                         }
{*********************************************************}

unit TabPanel;

interface

uses SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, ExtCtrls, Tabs;

type
  TTabPanel = class(TCustomPanel)
  private
    { Private declarations }
    FTabs: TStrings;
    FTabIndex: Integer;
    FOnChange: TTabChangeEvent;
    FNotebook: TNotebook;
    ChangingPage: Boolean;
    procedure SetTabs(Value: TStrings);
    procedure SetTabIndex(Value: Integer);
    procedure SetNotebook(Value: TNotebook);
    procedure HandlePageChange(Sender: TObject);
    procedure FreeHandlesOnPage(n: Integer);
    procedure InvalidateTabs;
    procedure CMFocusChanged(var Message: TCMFocusChanged); message CM_FOCUSCHANGED;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
  protected
    { Protected declarations }
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function GetClientRect: TRect; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(Aowner: TComponent); override;
    destructor Destroy; override;
  published
    property Tabs: TStrings read FTabs write SetTabs;
    property TabIndex: Integer read FTabIndex write SetTabIndex;
    property OnChange: TTabChangeEvent read FOnChange write FOnChange;
    property Notebook: TNotebook read FNotebook write SetNotebook;
    property TabStop;
  end;

procedure Register;

implementation

constructor TTabPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Font.Name := 'MS Sans Serif';
  Font.Size := 8;
  Font.Style := [];
  ControlStyle := ControlStyle + [csDesignInteractive, csOpaque];
  TabStop := True;
  FTabs := TStringList.Create;
  FTabs.Add('General');
end;

destructor TTabPanel.Destroy;
begin
  FTabs.Free;
  inherited Destroy;
end;

procedure TTabPanel.SetTabs(Value: TStrings);
begin
  FTabs.Assign(Value);
  Invalidate;
end;

procedure TTabPanel.InvalidateTabs;
var
  R: TRect;
begin
  R := Rect(0, 0, Width, 21);
  InvalidateRect(Handle, @R, false);
end;

procedure TTabPanel.SetTabIndex(Value: Integer);
var
  SilentChange: Boolean;
  Previous: Integer;
  Allow: Boolean;
begin
  if (Value >= 0) and (Value < FTabs.Count) and (Value <> FTabIndex) then
  begin
    Previous := FTabIndex;
    SilentChange := (csReading in ComponentState) or (csDestroying in ComponentState);
    if not SilentChange then
    begin
      if Assigned(FOnChange) then
      begin
        Allow := true;
        FOnChange(self, Value, Allow);
        if not Allow then Exit;
      end;
    end;
    FTabIndex := Value;
    InvalidateTabs;
    if FNotebook <> nil then
    begin
      { blocks recursive calls to HandlePageChange }
      ChangingPage := True;
      FNotebook.PageIndex := TabIndex;
      ChangingPage := False;
    end;
    if not SilentChange then FreeHandlesOnPage(previous);
  end;
end;

procedure TTabPanel.HandlePageChange(Sender: TObject);
var
  i: Integer;
begin
  if not ChangingPage then
  begin
    if (FNotebook.Pages.Count <> FTabs.Count) then
      FTabs.Assign(FNotebook.Pages);
    i := FNotebook.PageIndex;
    if (i >= 0) and (i < FTabs.Count) then
    begin
      FTabIndex := i;
      Invalidate;
    end;
  end;
end;

procedure TTabPanel.SetNotebook(Value: TNotebook);
begin
  if (Value = nil) and (FNoteBook <> nil) then
    FNotebook.OnPageChanged := nil;
  FNotebook := Value;
  if (FNotebook <> nil) then
  begin
    Tabs := FNotebook.Pages;
    TabIndex := FNotebook.PageIndex;
    FNotebook.OnPageChanged := HandlePageChange;
  end;
end;

procedure TTabPanel.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (AComponent = FNotebook) and (Operation = opRemove) then
    SetNotebook(nil);
end;

function TTabPanel.GetClientRect: TRect;
begin
  { Exclude the tabbed area }
  Result := Rect(0, 20, Width - 1, Height - 1);
end;

procedure TTabPanel.Paint;

var
  buffer: TBitmap;

procedure PaintShadowEdge(i, e: Integer; big: boolean);
begin
  with buffer.Canvas do if big then
  begin
    Pen.Color := clWindowFrame;
    MoveTo(e + 1, 2);
    LineTo(e + 1, 20);
    Pixels[e, 1] := Pen.Color;
    Pen.Color := clBtnShadow;
    MoveTo(e, 2);
    LineTo(e, 20);
  end
  else
  begin
    Pen.Color := clWindowFrame;
    MoveTo(e - 1, 4);
    LineTo(e - 1, 20);
    Pixels[e - 2, 3] := Pen.Color;
    Pen.Color := clBtnShadow;
    MoveTo(e - 2, 4);
    LineTo(e - 2, 20);
  end;
end;

procedure PaintEdge(i, e: Integer);
begin
  with buffer.Canvas do if (i = TabIndex) then
  begin
    Pen.Color := clBtnHighlight;
    MoveTo(e, 2);
    LineTo(e, 20);
    Pixels[e + 1, 1] := Pen.Color;
  end
  else
  begin
    if (i = TabIndex+1) then
      PaintShadowEdge(i, e, true)
    else
    begin
      Pen.Color := clBtnHighlight;
      MoveTo(e, 4);
      LineTo(e, 20);
      Pixels[e + 1, 3] := Pen.Color;
      if (i > 0) then PaintShadowEdge(i, e, false);
    end
  end
end;

var
  x1, x2, y, w, h, i, tx, ty: Integer;
  s: string;

begin {TTabPanel.Paint}
  buffer := TBitmap.Create;
  buffer.Width := Width;
  buffer.Height := 21;
  try
    with Canvas do
    begin
      Brush.Style := bsSolid;
      Brush.Color := Color;
      FillRect(Rect(0, 21, Width - 2, Height - 2));
      { top left highlight }
      Pen.Color := clBtnHighlight;
      MoveTo(0, 20);
      LineTo(0, Height - 1);
      { bottom left shadow }
      Pen.Color := clBtnShadow;
      MoveTo(0, Height - 2);
      LineTo(Width - 2, Height - 2);
      LineTo(Width - 2, 20);
      { bottom left edge }
      Pen.Color := clWindowFrame;
      MoveTo(Width - 1, 20);
      LineTo(Width - 1, Height - 1);
      LineTo(-1, Height - 1);
    end;
    with Buffer.Canvas do
    begin
      Brush.Style := bsSolid;
      Brush.Color := Color;
      FillRect(Rect(0, 0, Width, 21));
      { Change the font here because TextWidth needs it very soon }
      Font.Assign(self.Font);
    end;
    { This bit is quite tricky.
      x1 is the approximate left edge of the current tab
      x2 is the approximate right edge
      At the end of each iteration, x1 is assigned to x2, so the tabs move
      across the control. }
    x1 := 2;
    for i := 0 to Tabs.Count - 1 do
    begin
      s := Tabs[i];
      w := buffer.Canvas.TextWidth(s);
      h := buffer.Canvas.TextHeight(s);
      x2 := x1 + w + 12;
      if (i = TabIndex) then y := 0
      else y := 2;
      with buffer.Canvas do
      begin
        Brush.Style := bsClear;
        tx := x1 - 1 + (x2 - x1 - w) div 2;
        ty := y + 3;
        TextOut(tx, ty, s);
        if (i = TabIndex) and Focused then
        DrawFocusRect(Bounds(tx - 2, ty - 1, w + 4, h + 2));
        Pen.Color := clBtnHighlight;
        if (i = FTabIndex - 1) then
        begin
          MoveTo(x1 + 2, y);
          LineTo(x2 - 1, y);
          PaintEdge(i, x1);
        end
        else if (i = FTabIndex + 1) then
        begin
          MoveTo(x1, y);
          LineTo(x2 - 2, y);
          PaintEdge(i, x1);
        end
        else if (i = FTabIndex) then
        begin
          MoveTo(x1, y);
          LineTo(x2, y);
          MoveTo(0, 20);
          LineTo(x1 - 1, 20);
          MoveTo(x2 + 1, 20);
          LineTo(Width - 1, 20);
          PaintEdge(i, x1 - 2);
        end
        else
        begin
          MoveTo(x1 + 2, y);
          LineTo(x2 - 2, y);
          PaintEdge(i, x1);
        end;
      end;
      { Special case for rightmost tab edge }
      if (i = Tabs.Count - 1) then PaintShadowEdge(i, x2, i = TabIndex);
      x1 := x2;
      { Store the right hand edge of each tab in the Objects array so that
        the mouse handler can make use of it. }
      FTabs.Objects[i] := TObject(x1);
    end;
    Canvas.Draw(0, 0, buffer);
  finally
    buffer.Free;
  end;
end;

type
  TSurfaceWin = class(TWinControl);

procedure TTabPanel.FreeHandlesOnPage(n: Integer);
begin
  if (Notebook <> nil) and not (csDesigning in ComponentState) and
    (n >= 0) and (n < Notebook.Pages.Count) then
    begin
      { DestroyHandle introduces a small delay.  Calling Update first will
        repaint the tabbed notebook and hide the delay from the user }
      Update;
      {LockWindowUpdate(Handle);}
      TSurfaceWin(Notebook.Pages.Objects[n]).DestroyHandle;
      {LockWindowUpdate(0);}
    end;
end;

procedure TTabPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
  Form: TForm;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if ((Button = mbLeft) or (csDesigning in ComponentState)) and (Y < 20) then
    for i := 0 to FTabs.Count - 1 do
      if X < Longint(FTabs.Objects[i]) then
      begin
        TabIndex := i;
        if csDesigning in ComponentState then
        begin
          Form := GetParentForm(self);
          if (Form <> nil) and (Form.Designer <> nil) then
            Form.Designer.Modified;
        end;
        Break;
      end;
end;

procedure TTabPanel.CMFocusChanged(var Message: TCMFocusChanged);
begin
  inherited;
  InvalidateTabs;
end;

procedure TTabPanel.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Focused then
  begin
    if Key = VK_RIGHT then
      TabIndex := (TabIndex + 1) mod FTabs.Count
    else if Key = VK_LEFT then
      TabIndex := (FTabIndex + FTabs.Count - 1) mod FTabs.Count;
  end;
end;

procedure TTabPanel.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  inherited;
  Message.Result := DLGC_WANTARROWS;
end;

procedure Register;
begin
  RegisterComponents('Samples', [TTabPanel]);
end;

end.
