unit Finder;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, FileCtrl, Buttons, Picbtn;

type
  TFolderFinder = class(TForm)
    Folder1: TDirectoryListBox;
    PicBtn1: TPicBtn;
    PicBtn2: TPicBtn;
    Drive1: TDriveComboBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    procedure Drive1Change(Sender: TObject);
    procedure Folder1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FolderFinder: TFolderFinder;
  INIFile, SelectedFolder : string;

implementation

{$R *.DFM}

procedure TFolderFinder.Drive1Change(Sender: TObject);
begin
 Folder1.Drive := Drive1.Drive;
end;

procedure TFolderFinder.Folder1Change(Sender: TObject);
begin
 INIFile := Folder1.Directory;
 SelectedFolder := Folder1.Directory;
 Label3.Caption := 'Path: ' + Folder1.Directory;
end;

procedure TFolderFinder.FormCreate(Sender: TObject);
begin
 Label3.Caption := 'Path: ' + Folder1.Directory;
 INIFile := Folder1.Directory;
 SelectedFolder := Folder1.Directory;
end;

end.
