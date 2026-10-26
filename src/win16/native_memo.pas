{ SPDX-License-Identifier: GPL-2.0-or-later
  Multi-line Win16 EDIT with Delphi 1's TMemo interface. Like TEdit, the whole
  text is a short string of at most 255 bytes, line breaks included. }
unit native_memo;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This memo control requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Controls, native_edit;
type
  TScrollStyle = (ssNone, ssHorizontal, ssVertical, ssBoth);
  { Lines are the CR/LF-separated parts of Text, not the wrapped rows. }
  TMemo = class(TEdit)
  private
    FLines: TStrings;
    FScrollBars: TScrollStyle;
    FWordWrap, FWantReturns, FWantTabs: Boolean;
    procedure SetLines(Value: TStrings);
    procedure SetScrollBars(Value: TScrollStyle);
    procedure SetWordWrap(Value: Boolean);
  protected
    function ExtraStyle: DWORD; override;
    procedure WndProc(var M: TMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Lines: TStrings read FLines write SetLines;
    { Fixed once the window exists. }
    property ScrollBars: TScrollStyle read FScrollBars write SetScrollBars default ssNone;
    { Fixed once the window exists. }
    property WordWrap: Boolean read FWordWrap write SetWordWrap default True;
    property WantReturns: Boolean read FWantReturns write FWantReturns default True;
    property WantTabs: Boolean read FWantTabs write FWantTabs default False;
  end;
implementation
uses Win31, native_window;
type
  TMemoStrings = class(TStrings)
  private
    FMemo: TMemo;
    procedure Split(List: TStrings);
    procedure Join(List: TStrings);
  protected
    function Get(Index: Integer): AnsiString; override;
    function GetCount: Integer; override;
    procedure Put(Index: Integer; const S: AnsiString); override;
  public
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: AnsiString); override;
  end;
procedure TMemoStrings.Split(List: TStrings);
var Rest: string; Break: Integer;
begin
  Rest := FMemo.Text;
  if Rest = '' then Exit;
  repeat
    Break := Pos(#13#10, Rest);
    if Break = 0 then begin List.Add(Rest); Exit; end;
    List.Add(Copy(Rest, 1, Break - 1));
    System.Delete(Rest, 1, Break + 1);
  until False;
end;
procedure TMemoStrings.Join(List: TStrings);
var Text: string; I: Integer;
begin
  Text := '';
  for I := 0 to List.Count - 1 do
  begin
    if Length(Text) + Length(List[I]) + 2 * Ord(I > 0) > 255 then
      raise ENativeWindowError.Create('Memo text exceeds 255 bytes');
    if I > 0 then Text := Text + #13#10;
    Text := Text + List[I];
  end;
  FMemo.Text := Text;
end;
function TMemoStrings.Get(Index: Integer): AnsiString;
var List: TStringList;
begin
  List := TStringList.Create;
  try
    Split(List);
    if (Index < 0) or (Index >= List.Count) then raise EStringListError.Create('List index out of bounds');
    Result := List[Index];
  finally List.Free; end;
end;
function TMemoStrings.GetCount: Integer;
var List: TStringList;
begin
  List := TStringList.Create;
  try Split(List); Result := List.Count;
  finally List.Free; end;
end;
procedure TMemoStrings.Put(Index: Integer; const S: AnsiString);
var List: TStringList;
begin
  List := TStringList.Create;
  try Split(List); List[Index] := S; Join(List);
  finally List.Free; end;
end;
procedure TMemoStrings.Clear;
begin FMemo.Text := ''; end;
procedure TMemoStrings.Delete(Index: Integer);
var List: TStringList;
begin
  List := TStringList.Create;
  try Split(List); List.Delete(Index); Join(List);
  finally List.Free; end;
end;
procedure TMemoStrings.Insert(Index: Integer; const S: AnsiString);
var List: TStringList;
begin
  List := TStringList.Create;
  try Split(List); List.Insert(Index, S); Join(List);
  finally List.Free; end;
end;
constructor TMemo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLines := TMemoStrings.Create; TMemoStrings(FLines).FMemo := Self;
  FWordWrap := True; FWantReturns := True;
  AutoSelect := False;
  SetBounds(0, 0, 185, 89);
end;
destructor TMemo.Destroy;
begin
  inherited Destroy;
  FLines.Free;
end;
procedure TMemo.SetLines(Value: TStrings);
begin FLines.Assign(Value); end;
procedure TMemo.SetScrollBars(Value: TScrollStyle);
begin
  if Value = FScrollBars then Exit;
  if Handle <> 0 then raise ENativeWindowError.Create('Memo scroll bars cannot change after creation');
  FScrollBars := Value;
end;
procedure TMemo.SetWordWrap(Value: Boolean);
begin
  if Value = FWordWrap then Exit;
  if Handle <> 0 then raise ENativeWindowError.Create('Memo word wrap cannot change after creation');
  FWordWrap := Value;
end;
function TMemo.ExtraStyle: DWORD;
begin
  Result := ES_MULTILINE or ES_AUTOVSCROLL;
  if not FWordWrap then Result := Result or ES_AUTOHSCROLL;
  if FWantReturns then Result := Result or ES_WANTRETURN;
  if FScrollBars in [ssVertical, ssBoth] then Result := Result or WS_VSCROLL;
  if FScrollBars in [ssHorizontal, ssBoth] then Result := Result or WS_HSCROLL;
end;
procedure TMemo.WndProc(var M: TMessage);
begin
  inherited WndProc(M);
  if M.Msg = WM_GETDLGCODE then
  begin
    if FWantTabs then M.Result := M.Result or DLGC_WANTTAB
    else M.Result := M.Result and not DLGC_WANTTAB;
    if not FWantReturns then M.Result := M.Result and not DLGC_WANTALLKEYS;
  end;
end;
end.
