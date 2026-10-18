{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.1                                                   }
{    Copyright (C) 1998-1999 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    This program is free software; you can redistribute it and/or modify  }
{    it under the terms of the GNU General Public License as published by  }
{    the Free Software Foundation; either version 2 of the License, or     }
{    (at your option) any later version.                                   }
{                                                                          }
{    This program is distributed in the hope that it will be useful,       }
{    but WITHOUT ANY WARRANTY; without even the implied warranty of        }
{    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         }
{    GNU General Public License for more details.                          }
{                                                                          }
{    You should have received a copy of the GNU General Public License     }
{    along with this program; if not, write to the Free Software           }
{    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.             }
{                                                                          }
{**************************************************************************}

unit CalForm;

{ TCalForm is the common ancestor of most of Calmira's modeless windows,
  and you should use it for other modeless windows that you add.  The
  main feature is the use of WMSettingsChanged to trigger the
  SettingsChanged method.  Descendants override this to adjust their
  properties depending on which settings have been modified.

  The StretchShift method adjusts the controls on a form when it is
  resized.  Call it from the OnResize handler.

  WM_NCRBUTTONDOWN is intercepted to popup the list of open windows.

  Finally, ShowNormal is provided to make it easier to display a
  window, whatever state it is in.
}

interface

uses ExtForm, Messages, Classes, CalMsgs, Settings, Controls, WinTypes;

const
  { some magic numbers! }
  SC_SIZELEFT        = SC_SIZE + 1;
  SC_SIZERIGHT       = SC_SIZE + 2;
  SC_SIZETOP         = SC_SIZE + 3;
  SC_SIZETOPLEFT     = SC_SIZE + 4;
  SC_SIZETOPRIGHT    = SC_SIZE + 5;
  SC_SIZEBOTTOM      = SC_SIZE + 6;
  SC_SIZEBOTTOMLEFT  = SC_SIZE + 7;
  SC_SIZEBOTTOMRIGHT = SC_SIZE + 8;
  SC_DRAGMOVE        = SC_SIZE + 9;

type
  TStretchFlag = (stLeft, stTop, stWidth, stHeight);
  TStretchFlags = set of TStretchFlag;

  TCalForm = class(TExtForm)
  private
    FMinimumWidth: Integer;
    FMinimumHeight: Integer;
    OldClientWidth: Integer;
    OldClientHeight: Integer;
    SizeDelta: TPoint;
    procedure WMNCRButtonDown(var Msg: TWMNCRButtonDown); message WM_NCRBUTTONDOWN;
    procedure WMSettingsChanged(var Msg: TMessage); message WM_SETTINGSCHANGED;
    procedure WMGetMinMaxInfo(var Msg: TWMGetMinMaxInfo); message WM_GETMINMAXINFO;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Loaded; override;
    procedure Resize; override;
    procedure StretchShift(const C: array of TControl; Flags: TStretchFlags);
  public
    procedure SettingsChanged(Changes: TSettingChanges); virtual;
    procedure ShowNormal;
    procedure EnableControls(Enable: Boolean);
    property MinimumWidth: Integer read FMinimumWidth write FMinimumWidth;
    property MinimumHeight: Integer read FMinimumHeight write FMinimumHeight;
  end;

implementation

uses Forms, Desk, WinProcs, MiscUtil;

procedure TCalForm.WMNCRButtonDown(var Msg: TWMNCRButtonDown);
begin
  with Msg do
    if (WindowState <> wsMinimized) and (HitTest = HTCAPTION) then
      Desktop.WindowMenu.Popup(XCursor, YCursor)
    else inherited;
end;

procedure TCalForm.WMSettingsChanged(var Msg: TMessage);
begin
  SettingsChanged(TSettingChanges(Msg.wParam));
end;

procedure TCalForm.WMGetMinMaxInfo(var Msg: TWMGetMinMaxInfo);
begin
  inherited;
  with Msg.MinMaxInfo^ do
  begin
    ptMinTrackSize.X := FMinimumWidth;
    ptMinTrackSize.Y := FMinimumHeight;
  end;
end;

procedure TCalForm.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Cmd: Word;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (WindowState = wsMaximized) or (Button = mbRight) then Exit;
  ReleaseCapture;
  if (x <= 16) and (y <= 16) then Cmd := SC_SIZETOPLEFT
  else if (x <= 16) and (y >= ClientHeight - 16) then Cmd := SC_SIZEBOTTOMLEFT
  else if (x >= ClientWidth - 16) and (y <= 16) then Cmd := SC_SIZETOPRIGHT
  else if (x >= ClientWidth - 16) and (y >= ClientHeight - 16) then Cmd := SC_SIZEBOTTOMRIGHT
  else if (x <= 4) then Cmd := SC_SIZELEFT
  else if (y <= 4) then Cmd := SC_SIZETOP
  else if (x >= ClientWidth - 5) then Cmd := SC_SIZERIGHT
  else if (y >= ClientHeight - 5) then Cmd := SC_SIZEBOTTOM
  else Cmd := 0;
  Perform(WM_SYSCOMMAND, Cmd, 0);
end;

procedure TCalForm.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if ((x <= 16) and (y <= 16)) or ((x >= ClientWidth - 16) and
    (y >= ClientHeight - 16)) then Cursor := crSizeNWSE
  else if ((x >= ClientWidth - 16) and (y <= 16)) or ((x <= 16) and
    (y >= ClientHeight - 16)) then Cursor := crSizeNESW
  else if (x <= 4) or (x >= ClientWidth - 5) then Cursor := crSizeWE
  else if (y <= 4) or (y >= ClientHeight - 5) then Cursor := crSizeNS
  else Cursor := crDefault;
end;

procedure TCalForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if DesktopParent then Params.WndParent := GetDesktopWindow;
end;

procedure TCalForm.Loaded;
begin
  inherited Loaded;
  FMinimumWidth := Width;
  FMinimumHeight := Height;
  OldClientWidth := ClientWidth;
  OldClientHeight := ClientHeight;
end;

procedure TCalForm.Resize;
begin
  if WindowState <> wsMinimized  { 3.0 } then
  begin
    SizeDelta.X := ClientWidth - OldClientWidth;
    SizeDelta.Y := ClientHeight - OldClientHeight;
    OldClientWidth := ClientWidth;
    OldClientHeight := ClientHeight;
  end;
  inherited Resize;
end;

procedure TCalForm.StretchShift(const C: array of TControl;
  Flags: TStretchFlags);
var
  i, L, T, W, H: Integer;
begin
  for i := 0 to High(C) do with C[i] do
  begin
    L := Left;
    T := Top;
    W := Width;
    H := Height;
    if stLeft in Flags then Inc(L, SizeDelta.x);
    if stTop in Flags then Inc(T, SizeDelta.y);
    if stWidth in Flags then Inc(W, SizeDelta.x);
    if stHeight in Flags then Inc(H, SizeDelta.y);
    SetBounds(L, T, W, H);
  end;
end;

procedure TCalForm.SettingsChanged(Changes : TSettingChanges);
begin
end;

procedure TCalForm.ShowNormal;
begin
  WindowState := wsNormal;
  Show;
end;

procedure TCalForm.EnableControls(Enable: Boolean);
var
  i: Integer;
begin
  for i := 0 to ControlCount-1 do Controls[i].Enabled := Enable;
end;

end.

