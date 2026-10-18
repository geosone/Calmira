{*********************************************************}
{                                                         }
{    Calmira Visual Component Library 3.1                 }
{    by Li-Hsin Huang,                                    }
{    released into the public domain july 2000            }
{                                                         }
{*********************************************************}

unit Notepad;

interface

uses SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms;

type
  TNotepad = class(TComponent)
  private
    { Private declarations }
    FStrings: TStrings;
  protected
    { Protected declarations }
    procedure SetStrings(Value: TStrings);
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    { Published declarations }
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
  RegisterComponents('Samples', [TNotepad]);
end;

end.

