unit Vclopdlg;

interface
uses Classes, Dialogs, SysUtils, WinProcs, WinTypes,
     CalMsgs,Forms;

type
POpDlgParams = ^TOpDlgParams;
TOpDlgParams = record
    FFileName,FDefaultDir:string;
    FFilter,FTitle: string;
    FFiles: TStringList;
    FOptions : TOpenOptions;
    FOwner: TComponent;
    FExecute: Boolean;
    FReturned: Boolean;
end;
TCallbackOpenFunction = function (var FFileName,FDefaultDir:string;
                       FFilter,FTitle: string;
                       FFiles: TStringList;
                       FOptions : TOpenOptions;
                       FOwner: TComponent): Boolean;
  PCallbackOpenFunction = ^TCallbackOpenFunction;
  TDlgCreateRecord = record
    Func : PCallbackOpenFunction;
  end;
  TCalOpenDialog = class(TComponent)
  private
    {Private declarations}
    FFileName, FDefaultDir,FFilter,FTitle: string;
    FFiles: TStringList;
    FOptions : TOpenOptions;
  public
    {public declarations}
    property Files: TStringList read FFiles;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: boolean;
  published
    {Published declarations}
    property FileName: String read FFileName write FFileName;
    property Filter: string read FFilter write FFilter;
    property Title: string read FTitle write FTitle;
    property DefaultDir: string read FDefaultDir write FDefaultDir;
    property Options: TOpenOptions read FOptions write FOptions;
end;

procedure Register;
function DefaultOpDlg (var FFileName,FDefaultDir:string;
                       FFilter,FTitle: string;
                       FFiles: TStringList;
                       FOptions : TOpenOptions;
                       FOwner: TComponent): Boolean;far;

implementation

var OPEN_FILE_DLG_EX: TCallbackOpenFunction;

constructor TCalOpenDialog.Create(AOwner: TComponent);
var
  cr : TDlgCreateRecord;
begin
inherited Create(AOwner);
FFiles := TStringList.Create;
FFileName := EmptyStr;
FDefaultDir := EmptyStr;
FFilter := EmptyStr;
FTitle := EmptyStr;
FOptions := [ofFileMustExist,ofPathMustExist];
end;

destructor TCalOpenDialog.Destroy;
begin
FFiles.Destroy;
inherited Destroy;
end;

function TCalOpenDialog.Execute: boolean;
var
 Calmira: HWnd;
 Params:TOpDlgParams;
begin
  Calmira := FindWindow('TApplication', 'Calmira');
  if Calmira = 0 then
    begin
    Result := DefaultOpDlg(FFileName,FDefaultDir,FFilter,FTitle,FFiles,FOptions,Owner);
    end
  else
    begin
    Params.FFileName := FFileName;
    Params.FDefaultDir := FDefaultDir;
    Params.FFilter := FFilter;
    Params.FTitle := FTitle;
    Params.FFiles := FFiles;
    Params.FOptions := FOptions;
    PArams.FReturned := false;
    Params.FExecute := False;
    PostMessage(Calmira, WM_CALMIRA, CM_GETOPENDLGFUNC,LongInt(@Params));
    FFileName := Params.FFileName;
    FDefaultDir := Params.FDefaultDir;
    Result := Params.FExecute;
    end;
end;

function DefaultOpDlg (var FFileName,FDefaultDir:string;
                       FFilter,FTitle: string;
                       FFiles: TStringList;
                       FOptions : TOpenOptions;
                       FOwner: TComponent): Boolean;
begin
with TOpenDialog.Create(FOwner) do
  begin
  Options := FOptions;
  Filter := FFilter;
  FileName := FFileName;
  Title := FTitle;
  InitialDir := FDefaultDir;
  Result := Execute;
  if Result then
   begin
   FFileName := FileName;
   FFiles.Assign(Files);
   FDefaultDir := InitialDir;
   end;
  Destroy;
  end;
end;

procedure Register;
begin
  RegisterComponents('Dialogs', [TCalOpenDialog]);
end;

end.
