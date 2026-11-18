{**************************************************************************}
{                                                                          }
{    Calmira Reborn shell for Microsoft(R) Windows(TM) 3.1                 }
{    Version 5.0                                                           }
{    Copyright (C) 2022-2023 Hunter Turcin                                      }
{    Copyright (C) 2004-2007 Alexandre Rodrigues de Sousa                  }
{    Copyright (C) 1998-2002 Calmira Online!                               }
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

unit MyDocs;

{ Shortcuts are implemented as ordinary forms that stay minimized.
  Each shortcut contains a TReference which handles the interaction
  with the main engine.  TDesktop is responsible for loading and
  saving shortcuts. }

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Controls,
  Forms, Dialogs, Dropclnt, DragDrop, IniFiles, Referenc, CalForm, CalMsgs,
  Sysmenu, Settings, SysRefer;

type
  TfrmMyDocs = class(TCalForm)
    DropClient: TDropClient;
    SystemMenu: TSystemMenu;
    procedure FormDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure FormDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure DropClientDropFiles(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    { Private declarations }
    FRef: TSystemReference;
    LastMouseDown: Longint;
    Clicking: Boolean; { inside a left click on the icon }
    _Active: Boolean;
    procedure WMShade(var Msg: TWMActivate); message WM_ACTIVATE;
    procedure WMQueryOpen(var Msg: TWMQueryOpen); message WM_QUERYOPEN;
    procedure WMOpenShort(var Msg: TMsg); message WM_OPENSHORT;
    procedure WMCommand(var Msg: TMessage); message WM_COMMAND;
    procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMNCLButtonDown(var Msg: TWMNCLButtonDown); message WM_NCLBUTTONDOWN;
    procedure WMPaint(var Msg: TWMPaint); message WM_PAINT;
    procedure WMMouseActivate(var Msg: TWMMouseActivate); message WM_MOUSEACTIVATE;
    procedure WMLButtonDblClk(var Msg: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
    procedure WMNCRButtonDown(var Msg: TWMNCRButtonDown); message WM_NCRBUTTONDOWN;
    procedure RefChange(Sender: TObject);
  public
    { Public declarations }
    property Ref: TSystemReference read FRef;
    procedure SettingsChanged(Changes: TSettingChanges); override;
    procedure LoadFromIni(ini: TIniFile; const section: string);
    procedure SaveToIni(ini: TIniFile; const section : string);
  end;

implementation

{$IFNDEF FPC}{$R *.dfm}{$ENDIF}

uses {$IFDEF FPC}Win31, {$ENDIF}Desk, Resource, IconWin, ShellAPI, FileMan, MultiGrd, WasteBin, FileFind,
  Drives, Files, Strings, MiscUtil, CompSys, Graphics, Locale, ShutDown, Environs,
  language_catalog, LfnUtils;

{ The default name is stored in English and shown in the catalogue's
  language, as Windows XP names the folder in its own language. }
const DefaultCaption = 'My Documents';

function LocalCaption: string;
begin
  LocalCaption := LanguageText('Desktop', 'MyDocuments', DefaultCaption);
end;

const
  SC_PROPERTIES = SC_VSCROLL + 1024;
  QueryClose: Boolean = False;

procedure TfrmMyDocs.WMShade(var Msg: TWMActivate);
begin
  if (Msg.Active = WA_INACTIVE) then
   _Active := false
  else
   _Active := true;
   if DrawShadedIcons then
    Invalidate;
  {Perform(WM_PAINT,0,0);}
end;

procedure TfrmMyDocs.WMMouseActivate(var Msg: TWMMouseActivate);
begin
  { To prevent shortcuts being moved when the icon is dragged,
    the mouse down message is thrown away.  To catch double clicks,
    the DoubleClickSpeed from WIN.INI is used to time each message. }
  if StickyShorts or OneClickShorts then with Msg do
    if MouseMsg = WM_LBUTTONDOWN then
    begin
      Result := MA_NOACTIVATEANDEAT;
      if OneClickShorts or (GetTimerCount < LastMouseDown + DoubleClickSpeed) then
        Perform(WM_OPENSHORT, 0, 0);
    end
    else inherited
  else inherited;
  LastMouseDown := GetTimerCount;
end;

procedure TfrmMyDocs.WMNCLButtonDown(var Msg: TWMNCLButtonDown);
begin
  Clicking := True;
  try
    inherited;
  finally
    Clicking := False;
  end;
end;

procedure TfrmMyDocs.WMLButtonDblClk(var Msg: TWMLButtonDblClk);
begin
  PostMessage(Handle, WM_OPENSHORT, 0, 0);
end;

procedure TfrmMyDocs.WMNCRButtonDown(var Msg: TWMNCRButtonDown);
var
  p: TPoint;
begin
  SetActiveWindow(Handle);
  GetCursorPos(p);
  TrackPopupMenu(SystemMenu.Handle, TPM_LEFTALIGN or TPM_RIGHTBUTTON, p.X, p.Y, 0, Handle, nil);
end;

procedure TfrmMyDocs.WMQueryOpen(var Msg: TWMQueryOpen);
begin
  { New windows cannot be opened when inside SendMessage, so
    an extra message must be posted to remind the shortcut to open.
    0 is returned to keep the shortcut iconic }
  Msg.Result := 0;
  PostMessage(Handle, WM_OPENSHORT, 0, 0);
end;

procedure TfrmMyDocs.WMOpenShort(var Msg: TMsg);
begin
  Ref.Open;
end;

procedure TfrmMyDocs.WMCommand(var Msg: TMessage);
begin
  with Msg do PostMessage(Handle, WM_SYSCOMMAND, wParam, MakeLong(1, 1));
end;

procedure TfrmMyDocs.WMSysCommand(var Msg: TWMSysCommand);
var
  P: TPoint;
  R: TRect;
begin
  with Msg do
    case CmdType and $FFF0 of
      SC_CLOSE      : QueryClose := True;
      SC_PROPERTIES : if CanEditSettings then Ref.Edit;
      { Windows 3.1 opens the menu with it after a click on an icon
        that did not move it; Alt+Space is no click. }
      SC_KEYMENU    : if Clicking and not LeftClickShortMenu then Exit;
      SC_RESTORE    :
        begin
          { This extra code fixes the Alt-Tab activation bug.  Previously,
            Alt-Tabbing to Calmira when a shortcut was last active would
            generate an SC_RESTORE and open the shortcut again.

            We can now tell if this message was generated by Alt+Tab by
            examining the cursor position.  The "physical" cursor must be
            within the icon's boundaries, and also, Windows will provide
            a positive cursor feedback in XPos and YPos if the Open
            command was selected from the popup menu }
          GetCursorPos(P);
          with MinPosition do R := Bounds(X, Y, 32, 32);
          if not PtInRect(R, P) and (XPos = 0) and (YPos = 0) then Exit;
        end;
    end;
  inherited;
  QueryClose := False;
end;

procedure TfrmMyDocs.WMPaint(var Msg: TWMPaint);
begin
  inherited;
  if _Active and DrawShadedIcons then
   ShadeIcon(Canvas, Icon, 0, 0,Colors[ccIconSel])
{  if ShortArrows then
    Canvas.Draw(0, 32 - ShortArrow.Height, ShortArrow);}
end;

procedure TfrmMyDocs.FormDragDrop(Sender, Source: TObject; X, Y: Integer);
begin
  Ref.DragDrop(Source);
end;

procedure TfrmMyDocs.FormDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  Accept := (Source <> Computer.Grid) and ((Source <> Bin.Listbox) or
    (Ref.Kind <> rkFile));
end;

procedure TfrmMyDocs.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TfrmMyDocs.FormCreate(Sender: TObject);
var
  buf: array[0..31] of Char;
begin
  with SystemMenu do
  begin
    { 3.11 re-ordered }
    DeleteCommand(SC_SIZE);
    DeleteCommand(SC_CLOSE);
    DeleteCommand(SC_MINIMIZE);
    DeleteCommand(SC_MAXIMIZE);
    DeleteCommand(SC_TASKLIST);
    Delete(2);
    LoadString(HInstance, SMenuShortcutOpen, buf, 31);
    Rename(SC_RESTORE, buf);
    LoadString(HInstance, SMenuShortcutMove, buf, 31);
    Rename(SC_MOVE, buf);
    InsertSeperator(1);
{    LoadString(HInstance, SMenuShortcutRemove, buf, 31);
    Rename(SC_CLOSE, buf);}
    LoadString(HInstance, SMenuShortcutProperties, buf, 31);
    Insert(5, buf, SC_PROPERTIES);
  end;
  FRef := TSystemReference.Create;
  FRef.SystemString := 'MyDocs';
  FRef.OnChange := RefChange;
end;

procedure TfrmMyDocs.DropClientDropFiles(Sender: TObject);
begin
  Ref.AcceptFiles(DropClient.Files);
end;

procedure TfrmMyDocs.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  { QueryClose is set to True when the user deletes the shortcut
    from the popup menu.  During shutdown, this is False so shortcuts
    are closed without asking }
  CanClose := {not QueryClose or (CanEditSettings and (not ConfirmDelShort
    or (MsgDialogResFmt(SQueryDeleteShortcut, [Caption],
    mtConfirmation, mbOKCancel, 0) = mrOK)))} False;
end;

procedure TfrmMyDocs.RefChange(Sender: TObject);
begin
  Ref.AssignIcon(Icon);
  {Icon.Assign(icons.Get('MyDocs'));}
  Caption := Ref.Caption;
  Environment.Values['PERSONALFOLDER'] := Ref.Target;
end;

{ The short name Windows 95 gives a long one in an empty folder:
  "Eigene Dateien" is EIGENE~1, "Documenti" DOCUME~1 }
function ShortAlias(const Name: string): string;
var
  s: string;
  i: Integer;
begin
  s := '';
  for i := 1 to Length(Name) do
    if Name[i] in ['A'..'Z', 'a'..'z', '0'..'9'] then s := s + UpCase(Name[i])
    else if not (Name[i] in [' ', '.']) then s := s + '_';
  if (Length(s) > 8) or (s <> UpperCase(Name)) then s := Copy(s, 1, 6) + '~1';
  ShortAlias := s;
end;

procedure TfrmMyDocs.LoadFromIni(ini: TIniFile; const section: string);
var
  FileSystem: string;
  Flags: Word;
  Named: Boolean;
begin
  Named := ini.ReadString(section, 'Target', '') <> '';
  Ref.LoadFromIni(ini, section);
  { Without a folder in CALMIRA.INI, the one Windows 95 and 98 make, in the
    catalogue's language: C:\Eigene Dateien, or C:\EIGENE~1 where the drive
    has no long names. Calmira makes it, the RTL under its long name. }
  if not Named then
  begin
    if LGetVolumeInfo('C:\', FileSystem, Flags) and (Flags and $4000 <> 0) then
      Ref.Target := 'C:\' + LocalCaption
    else
      Ref.Target := 'C:\' + ShortAlias(LocalCaption);
    if not HDirectoryExists(Ref.Target) then
    try
      LMkDir(Ref.Target);
    except
      on Exception do ;
    end;
  end;
  if Ref.Kind <> rkFolder then
    begin
    {Ref.Kind := rkFolder;}
    Ref.Caption := DefaultCaption;
    if EnableLFN then
     Ref.Target := 'C:\My Documents'
    else
     Ref.Target := 'C:\MYDOCS~1';
    end;
  if Ref.Caption = DefaultCaption then Ref.Caption := LocalCaption;
  Environment.Values['PERSONALFOLDER'] := Ref.Target;
  MinPosition := Point(ini.ReadInteger(section, 'Left', 128),
    ini.ReadInteger(section, 'Top', 128));
  Update;
end;

procedure TfrmMyDocs.SaveToIni(ini: TIniFile; const section: string);
begin
  Ref.SaveToIni(ini, section);
  if Ref.Caption = LocalCaption then
    ini.WriteString(section, 'Caption', DefaultCaption);
  with MinPosition do
  begin
    ini.WriteInteger(section, 'Left', x);
    ini.WriteInteger(section, 'Top', y);
  end;
end;

procedure TfrmMyDocs.FormDestroy(Sender: TObject);
begin
  FRef.Free;
end;

procedure TfrmMyDocs.SettingsChanged(Changes: TSettingChanges);
begin
  if [scDesktop, scDisplay] * Changes <> [] then Repaint;
end;

procedure TfrmMyDocs.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  { 3.1 Show Quit dialog when ALT-F4 is pressed while shortcut has focus }
  if (Key = VK_F4) and (ssAlt in Shift) then
  begin
    Key := 0;
    ShowModalDialog(TQuitDlg);
  end;
{  if Key = VK_DELETE then
  begin
    QueryClose := True;
    Close;
  end;}
end;

end.

