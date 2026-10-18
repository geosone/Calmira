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

unit MenuEdit;

{ Start menu item editor

  This dialog accepts input through the EditItem procedure.  After
  the modal state is finished, the edited data can be retrieved
  through the DataString function }

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, ExtCtrls, Dialogs,
  StylSped, Icondlg, SysUtils, TabNotBk, TabPanel, Picbtn;

type
  TMenuEditDlg = class(TForm)
    IconDialog: TIconDialog;
    OpenDialog: TOpenDialog;
    TabPanel: TTabPanel;
    Notebook: TNotebook;
    Label1: TLabel;
    CaptionEdit: TEdit;
    Label2: TLabel;
    CommandEdit: TComboBox;
    Label3: TLabel;
    FolderEdit: TEdit;
    Label5: TLabel;
    BrowseIcon: TStyleSpeed;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    BrowseFolder: TStyleSpeed;
    BrowseCommand: TStyleSpeed;
    ShowCombo: TComboBox;
    Label4: TLabel;
    Bevel1: TBevel;
    Bevel2: TBevel;
    TargetIcon: TImage;
    CaptionLabel: TLabel;
    IconEdit: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BrowseCommandClick(Sender: TObject);
    procedure BrowseFolderClick(Sender: TObject);
    procedure BrowseIconClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    { 3.1 }
    procedure CaptionEditExit(Sender: TObject);
    procedure CommandEditExit(Sender: TObject);
  private
    { Private declarations }
    SaveHistory: Boolean;
    procedure AssignTargetIcon; { 3.1 }
  public
    { Public declarations }
    function DataString: string;
    function EditItem(const prompt, captext, data: string): TModalResult;
  end;

var
  MenuEditDlg: TMenuEditDlg;

implementation

{$R *.DFM}

uses Graphics, ShellAPI, Strings, Settings, Start, WinProcs, WinTypes,
  MiscUtil, Tree, RefEdit, Locale, Resource, Referenc, Internet;

procedure TMenuEditDlg.FormCreate(Sender: TObject);
begin
  Notebook.PageIndex := 0;
  ini.ReadStrings('IconSources', IconDialog.HistoryList);
  { 3.1 }
  BrowseCommand.Glyph.Handle := LoadBitmap(HInstance, 'BBBROWSE');
  BrowseIcon.Glyph.Handle := LoadBitmap(HInstance, 'BBBROWSE');
  BrowseFolder.Glyph.Handle := LoadBitmap(HInstance, 'BBBROWSE');
end;

procedure TMenuEditDlg.FormDestroy(Sender: TObject);
begin
  if SaveHistory then
    ini.WriteNewStrings('IconSources', IconDialog.HistoryList);
  MenuEditDlg := nil;
end;

procedure TMenuEditDlg.BrowseCommandClick(Sender: TObject);
var
  lctext: string;
begin
  with CommandEdit do
  begin
    lctext := Lowercase(Text);
    if Pos('$dossier', lctext) = 1 then
      Text := '$Dossier ' + SelectFolder(Copy(Text, 10, 255))
    else if Pos('$dossiergrandesicônes', lctext) + Pos('$dossiergrandesicones', lctext) = 1 then
      Text := '$DossierGrandesIcônes ' + SelectFolder(Copy(Text, 23, 255))
    else if Pos('$dossierpetitesicônes', lctext) + Pos('$dossierpetitesicones', lctext) = 1 then
      Text := '$DossierPetitesIcônes ' + SelectFolder(Copy(Text, 23, 255))
    else if Pos('$dossierliste', lctext) = 1 then
      Text := '$DossierDétails ' + SelectFolder(Copy(Text, 15, 255))
    else if Pos('$dossierdetails', lctext) + Pos('$dossierdétails', lctext) = 1 then
      Text := '$DossierDétails ' + SelectFolder(Copy(Text, 17, 255))
    else if OpenDialog.Execute then
      Text := Lowercase(OpenDialog.Filename);
  end;
  AssignTargetIcon; { 3.1 }
end;

procedure TMenuEditDlg.BrowseFolderClick(Sender: TObject);
begin
  FolderEdit.Text := SelectFolder(FolderEdit.Text);
end;

procedure TMenuEditDlg.BrowseIconClick(Sender: TObject);
begin
  with IconDialog do
  begin
    { Calmira 1.1 bug fix to search default file }
    if IconEdit.Text > '' then Filename := ExtractIconFile(IconEdit.Text)
    else Filename := FirstWord(CommandEdit.Text);
    Index := ExtractIconIndex(IconEdit.Text);
    if Execute then
    begin
      IconEdit.Text := Format('%s(%d)', [Filename, Index]);
      SaveHistory := True;
      AssignTargetIcon; { 3.1 }
    end;
  end;
end;

procedure TMenuEditDlg.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  if (ModalResult = mrOK) and IsBlank(CaptionEdit.Text) then
  begin
    ErrorMsgRes(SCaptionNeedsText);
    CanClose := False;
  end;
end;

function TMenuEditDlg.DataString: string;
begin
  Result := PackStartInfo(CommandEdit.Text, FolderEdit.Text,
    ExtractIconFile(IconEdit.Text),
    ShowCombo.ItemIndex, { 3.1 }
    ExtractIconIndex(IconEdit.Text));
end;

function TMenuEditDlg.EditItem(const prompt, captext, data: string): TModalResult;
begin
  Caption := prompt;
  with ExtractStartInfo(data) do
  begin
    CaptionLabel.Caption := captext;
    CaptionEdit.Text := captext;
    CommandEdit.Text := Command;
    FolderEdit.Text := Directory;
    if IconFile > '' then
      IconEdit.Text := Format('%s(%d)', [IconFile, IconIndex])
    else
      IconEdit.Text := '';
    { 3.1 }
    ShowCombo.ItemIndex := ShowMode;
    AssignTargetIcon;
  end;
  ActiveControl := CaptionEdit;
  Result := ShowModal;
end;

function IsSpecialItem(const s: string): Boolean;
begin
  Result := (s > '') and ((s[1] = '*') or (s[1] = '-'));
end;

{ 3.1 }

procedure TMenuEditDlg.CaptionEditExit(Sender: TObject);
begin
  CaptionLabel.Caption := CaptionEdit.Text;
end;

procedure TMenuEditDlg.CommandEditExit(Sender: TObject);
begin
  AssignTargetIcon;
end;

procedure TMenuEditDlg.AssignTargetIcon; { 3.1 }
var
  I: Integer;
begin
  if (IconEdit.Text = '') and IsURL(CommandEdit.Text) then
    begin
      { 3.1 -- Internet icon }
      TargetIcon.Picture.Icon.Assign(Icons.get('Internet'));
      Exit;
    end;
  if (IconEdit.Text > '') and (IconEdit.Text[1] = '<') then
  begin
    { Find an auxiliary image }
    i := 0;
    while i <= High(IconTable) do
      if CompareText(ExtractIconFile(IconEdit.Text), IconTable[i]) = 0 then
      begin
        TargetIcon.Picture.Icon.Assign(Icons.Get(IconToRes[i]));
        Exit;
      end
      else Inc(i);
  end;
  { Use a reference object to do the icon searching }
  FileRef.Target := FirstWord(Lowercase(CommandEdit.Text));
  FileRef.IconFile := ExtractIconFile(IconEdit.Text);
  FileRef.IconIndex := ExtractIconIndex(IconEdit.Text);
  FileRef.AssignIcon(TargetIcon.Picture.Icon);
end;

end.

