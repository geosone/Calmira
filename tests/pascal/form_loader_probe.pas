{ Form class for the DFM loader test; tests/form_loader_fixture.py writes its
  binary DFM and tools/dfm_loader.py generates form_loader_probe_dfm. }
unit form_loader_probe;
{$mode delphi}{$H-}
interface
uses Classes, Graphics, Controls, StdCtrls, ExtCtrls, Menus, Forms;
type
  TProbeBox = class(TCustomControl)
  private
    FValue: Integer;
    procedure SetValue(Value: Integer);
  public
    LoadingWhenSet, LoadedCalls: Integer;
    LoadingAfterLoaded: Boolean;
    procedure Loaded; override;
  published
    property Value: Integer read FValue write SetValue;
  end;
  TProbeForm = class(TForm)
    Title: TLabel;
    NameEdit: TEdit;
    OkButton: TButton;
    Agree: TCheckBox;
    Choices: TListBox;
    Line: TBevel;
    Book: TNotebook;
    PageEdit: TEdit;
    PageCheck: TCheckBox;
    Box: TProbeBox;
    Popup: TPopupMenu;
    OpenItem: TMenuItem;
    SubItem: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure NameChange(Sender: TObject);
  public
    CreateSawComponents: Boolean;
    CreateCount, Clicks, Changes: Integer;
  end;
  { No resource of its own: Create uses its ancestor's. }
  TDerivedProbe = class(TProbeForm);
  { No resource at all. }
  TOrphanForm = class(TForm);
var DestroyCount: Integer;
implementation
procedure TProbeBox.SetValue(Value: Integer);
begin
  FValue := Value;
  if csLoading in ComponentState then Inc(LoadingWhenSet);
end;
procedure TProbeBox.Loaded;
begin
  inherited Loaded;
  Inc(LoadedCalls);
  LoadingAfterLoaded := csLoading in ComponentState;
end;
procedure TProbeForm.FormCreate(Sender: TObject);
begin
  Inc(CreateCount);
  CreateSawComponents := (Box <> nil) and (Box.LoadedCalls = 1) and (SubItem <> nil);
end;
procedure TProbeForm.FormDestroy(Sender: TObject);
begin Inc(DestroyCount); end;
procedure TProbeForm.OkClick(Sender: TObject);
begin Inc(Clicks); end;
procedure TProbeForm.NameChange(Sender: TObject);
begin Inc(Changes); end;
end.
