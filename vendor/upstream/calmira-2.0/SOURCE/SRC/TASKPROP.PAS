{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.0                                                    }
{    Copyright (C) 1997  Li-Hsin Huang                                     }
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

unit Taskprop;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, Chklist, TabNotBk, ExtCtrls, Spin, StylSped;

type
  TTaskPropDlg = class(TForm)
    OKBtn: TBitBtn;
    CancelBtn: TBitBtn;
    Notebook: TTabbedNotebook;
    CheckList: TCheckList;
    AppTrayList: TListBox;
    Header1: THeader;
    Label1: TLabel;
    AddAppBtn: TStyleSpeed;
    RemoveBtn: TStyleSpeed;
    RefreshEdit: TSpinEdit;
    Label2: TLabel;
    Bevel1: TBevel;
    HelpBtn: TBitBtn;
    Bevel2: TBevel;
    Header2: THeader;
    Label3: TLabel;
    ExcludeList: TListBox;
    AddExclusionBtn: TStyleSpeed;
    RemoveExcludeBtn: TStyleSpeed;
    Bevel3: TBevel;
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure AppTrayListDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure AddAppBtnClick(Sender: TObject);
    procedure RemoveBtnClick(Sender: TObject);
    procedure Header1Sized(Sender: TObject; ASection, AWidth: Integer);
    procedure ExcludeListDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure Header2Sized(Sender: TObject; ASection, AWidth: Integer);
    procedure AddExclusionBtnClick(Sender: TObject);
    procedure RemoveExcludeBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

{
var
  TaskPropDlg: TTaskPropDlg;
}


implementation

{$R *.DFM}

uses Settings, CalMsgs, Strings, Dialogs, SysUtils, Locale;

procedure TTaskPropDlg.FormCreate(Sender: TObject);
begin
  Notebook.PageIndex := 0;

  CheckList.SetData(
    [StayVisible, ShrinkMax,
     Clock24, PopupRes, PopupDate,
     Animate, ButtonHints, ArrangeMin,
     HideMinApps, IconWindowTask, ExplorerTask,
     FullFolderPath, DocNameFirst,
     DocNameLower, TaskAlternateStretch]);

  ini.ReadSectionValues('Applet Tray', AppTrayList.Items);
  ini.ReadStrings('Exclude', ExcludeList.Items);
  RefreshEdit.Value := ini.ReadInteger('Taskbar', 'Refresh', 5);
end;

procedure TTaskPropDlg.OKBtnClick(Sender: TObject);
begin
  CheckList.GetData(
    [@StayVisible, @ShrinkMax,
     @Clock24, @PopupRes, @PopupDate,
     @Animate, @ButtonHints, @ArrangeMin,
     @HideMinApps, @IconWindowTask, @ExplorerTask,
     @FullFolderPath, @DocNameFirst,
     @DocNameLower, @TaskAlternateStretch]);

  SaveTaskProp;
  ini.EraseSection('Applet Tray');
  ini.WriteSectionValues('Applet Tray', AppTrayList.Items);
  ini.WriteStrings('Exclude', ExcludeList.Items);
  ini.WriteInteger('Taskbar', 'Refresh', RefreshEdit.Value);

  AnnounceSettingsChanged([scTaskbar]);
end;


procedure TTaskPropDlg.AppTrayListDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  with AppTrayList do begin
    Canvas.FillRect(Rect);
    Canvas.TextOut(Rect.Left+2, Rect.Top+1, GetStrKey(Items[Index]));
    Canvas.TextOut(Header1.SectionWidth[0], Rect.Top+1, GetStrValue(Items[Index]));
  end;
end;


procedure TTaskPropDlg.AddAppBtnClick(Sender: TObject);
var s: string;
begin
  s := '';
  if InputQuery(LoadStr(SAddApplet), LoadStr(SAppletFormat), s) and
    (s > '') then AppTrayList.Items.Add(s);
end;

procedure TTaskPropDlg.RemoveBtnClick(Sender: TObject);
begin
  with AppTrayList do
    if ItemIndex <> -1 then Items.Delete(ItemIndex);
end;

procedure TTaskPropDlg.Header1Sized(Sender: TObject; ASection,
  AWidth: Integer);
begin
  AppTrayList.Invalidate;
end;

procedure TTaskPropDlg.ExcludeListDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  with ExcludeList do begin
    Canvas.FillRect(Rect);
    Canvas.TextOut(Rect.Left+2, Rect.Top+1, GetStrKey(Items[Index]));
    Canvas.TextOut(Header2.SectionWidth[0], Rect.Top+1, GetStrValue(Items[Index]));
  end;
end;

procedure TTaskPropDlg.Header2Sized(Sender: TObject; ASection,
  AWidth: Integer);
begin
  ExcludeList.Invalidate;
end;

procedure TTaskPropDlg.AddExclusionBtnClick(Sender: TObject);
var s: string;
begin
  s := '';
  if InputQuery(LoadStr(SAddExclusion), LoadStr(SModuleClass), s) and
    (s > '') then ExcludeList.Items.Add(s);
end;

procedure TTaskPropDlg.RemoveExcludeBtnClick(Sender: TObject);
begin
  with ExcludeList do
    if ItemIndex <> -1 then Items.Delete(ItemIndex);
end;

end.
