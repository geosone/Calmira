{**************************************************************************}
{                                                                          }
{    Calmira II shell pour Microsoft® Windows(TM) 3.1                      }
{    Version française 3.3                                                 }
{    Copyright (C) 2000-2002 Jean Blanchard                                }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    Ce programme est libre ; vous pouvez le redistribuer et/ou le         }
{    modifier selon les termes de la Licence Publique Générale GNU telle   }
{   que publiée par la Free Software Foundation ; version 2 de la licence  }
{    ou (au choix) n'importe quelle version plus récente.                  }
{                                                                          }
{    Ce programme est distibué dans l'espoir qu'il sera utile, mais SANS   }
{    AUCUNE GARANTIE ; sans même la garantie implicite de                  }
{    COMMERCIALISATION ou d'APTITUDE A UN USAGE PARTICULIER. Voir la       }
{    licence publique générale pour plus de détails.                                        }
{                                                                          }
{    Vous devriez avoir reçue une copie de la licence publique générale    }
{    avec ce programme; si ce n'est pas le cas, écrivez à la Free          }
{    Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.    }
{                                                                          }
{--------------------------------------------------------------------------}

unit OpenFile;

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, Dialogs, Picbtn, StylSped,
  Registry;

type
  TOpenFileDlg = class(TForm)
    Combo: TComboBox;
    Label1: TLabel;
    Listbox: TListBox;
    OpenDialog: TOpenDialog;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    BrowseBtn: TStyleSpeed;
    Label2: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure BrowseBtnClick(Sender: TObject);
    procedure ListboxClick(Sender: TObject);
    procedure ListboxDblClick(Sender: TObject);
  private
    { Private declarations }
    IniCount: Integer;
    Changed: Boolean;
    reg: TRegistry;
  public
    { Public declarations }
    class function Execute: string;
  end;

implementation

{$R *.DFM}

uses WinProcs, SysUtils, Settings, Start, MiscUtil, Strings;

var
  OpenFileDlg: TOpenFileDlg;

procedure TOpenFileDlg.FormCreate(Sender: TObject);
var
  key, command: string[79];
  TempList: TStringList;
  i: Integer;
begin
  BrowseBtn.Glyph.Handle := LoadBitmap(HInstance, 'BBBROWSE');
  { Read the combobox history from ini }
  ini.ReadStrings('OpenFileWith', Combo.Items);
  if Combo.Items.Count > 0 then Combo.Text := Combo.Items[0];
  { Add entries from File Viewer section to listbox }
  ini.ReadSection('File Viewers', Listbox.Items);
  IniCount := ListBox.Items.Count;
  { 3.1 -- Add registered program to listbox }
  reg := TRegistry.Create;
  reg.OpenKey('', False);
  TempList := TStringList.Create;
  TempList.Sorted := False;
  i := 0;
  while reg.EnumKey(i, key) do
  begin
    if key[1] <> '.' then
    begin
      command := reg.ReadString(key + '\shell\open\command');
      if command > '' then TempList.Add(format('%s  (' + key + ')',
        [ExtractFilename(FirstWord(command))]));
    end;
    Inc(i);
  end;
  reg.CloseKey;
  with TempList do
  begin
    Sort;
    for i := 0 to Count - 1 do
      ListBox.Items.Add(Strings[i]);
    Free;
  end;
end;

class function TOpenFileDlg.Execute: string;
begin
  OpenFileDlg := TOpenFileDlg.Create(Application);
  try
    if OpenFileDlg.ShowModal = mrOK then
      Result := OpenFileDlg.Combo.Text
    else Result := '';
  finally
    FreeAndNil(OpenFileDlg);
  end;
end;

procedure TOpenFileDlg.FormDestroy(Sender: TObject);
begin
  if Changed then
    ini.WriteNewStrings('OpenFileWith', Combo.Items);
  reg.Free; { 3.1 }
end;

procedure TOpenFileDlg.OKBtnClick(Sender: TObject);
begin
  Changed := AddHistory(Combo) or Changed;
end;

procedure TOpenFileDlg.BrowseBtnClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    Combo.Text := Lowercase(OpenDialog.Filename);
end;

procedure TOpenFileDlg.ListboxClick(Sender: TObject);
var
  s: string;
begin
  with Listbox do
  begin
    if ItemIndex < IniCount then
      Combo.Text := ini.ReadString('File Viewers', Items[ItemIndex], '')
    else
    begin
      Unformat(Items[ItemIndex], '%S  (%s)', [@s, 79]);
      Combo.Text := reg.ReadString(s + '\shell\open\command');
    end;
  end;
end;

procedure TOpenFileDlg.ListboxDblClick(Sender: TObject);
begin
  OKBtn.Click;
end;

end.

