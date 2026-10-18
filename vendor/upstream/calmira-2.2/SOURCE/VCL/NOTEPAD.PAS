unit Notepad;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms;

type
  TNotepad = class(TComponent)
  private
    FStrings: TStrings;
  protected
    procedure SetStrings(Value: TStrings);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Strings: TStrings read FStrings write SetStrings;
  end;

procedure Register;

implementation

constructor TNotepad.Create( AOwner: TComponent );
begin
  inherited Create( AOwner );
  FStrings := TStringList.Create;
end;

destructor TNotepad.Destroy;
begin
  FStrings.Free;
  inherited Destroy;
end;

procedure TNotepad.SetStrings(Value: TStrings);
begin
  FStrings.Assign(Value);
end;

procedure Register;
begin
  RegisterComponents('Calmira', [TNotepad]);
end;

end.
