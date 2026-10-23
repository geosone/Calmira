{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 TClipboard for text and raw handles, owned by Application.Handle.
  Graphic and component formats (Assign, GetComponent) are not provided yet. }
unit Clipbrd;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Clipbrd unit requires Win16}{$ENDIF}
interface
uses SysUtils, WinTypes;
type
  EClipboardError = class(Exception);
  TClipboard = class(TObject)
  private
    FOpenRefCount: Integer;
    FEmptied: Boolean;
    function GetAsText: string;
    procedure SetAsText(const Value: string);
    function GetFormatCount: Integer;
    function GetFormat(Index: Integer): Word;
  public
    procedure Open;
    procedure Close;
    procedure Clear;
    function HasFormat(Format: Word): Boolean;
    function GetAsHandle(Format: Word): THandle;
    procedure SetAsHandle(Format: Word; Value: THandle);
    function GetTextBuf(Buffer: PChar; BufSize: Integer): Integer;
    procedure SetTextBuf(Buffer: PChar);
    property AsText: string read GetAsText write SetAsText;
    property FormatCount: Integer read GetFormatCount;
    property Formats[Index: Integer]: Word read GetFormat;
  end;
function Clipboard: TClipboard;
function SetClipboard(NewClipboard: TClipboard): TClipboard;
implementation
uses WinProcs, Forms;
var FClipboard: TClipboard;
function Clipboard: TClipboard;
begin
  if FClipboard = nil then FClipboard := TClipboard.Create;
  Result := FClipboard;
end;
function SetClipboard(NewClipboard: TClipboard): TClipboard;
begin
  Result := FClipboard;
  FClipboard := NewClipboard;
end;
procedure TClipboard.Open;
begin
  if FOpenRefCount = 0 then
  begin
    if not OpenClipboard(Application.Handle) then
      raise EClipboardError.Create('Cannot open clipboard');
    FEmptied := False;
  end;
  Inc(FOpenRefCount);
end;
procedure TClipboard.Close;
begin
  if FOpenRefCount = 0 then Exit;
  Dec(FOpenRefCount);
  if FOpenRefCount = 0 then CloseClipboard;
end;
procedure TClipboard.Clear;
begin
  Open;
  try
    EmptyClipboard;
    FEmptied := True;
  finally Close; end;
end;
function TClipboard.HasFormat(Format: Word): Boolean;
begin
  Result := IsClipboardFormatAvailable(Format);
end;
function TClipboard.GetAsHandle(Format: Word): THandle;
begin
  Open;
  try Result := GetClipboardData(Format);
  finally Close; end;
end;
procedure TClipboard.SetAsHandle(Format: Word; Value: THandle);
begin
  Open;
  try
    { One Open...Close block may hold several formats; empty only once. }
    if not FEmptied then begin EmptyClipboard; FEmptied := True; end;
    SetClipboardData(Format, Value);
  finally Close; end;
end;
function TClipboard.GetTextBuf(Buffer: PChar; BufSize: Integer): Integer;
var Data: THandle; Text: PChar;
begin
  Result := 0;
  if (Buffer = nil) or (BufSize <= 0) then Exit;
  Buffer[0] := #0;
  Open;
  try
    Data := GetClipboardData(CF_TEXT);
    if Data = 0 then Exit;
    Text := GlobalLock(Data);
    if Text = nil then Exit;
    try
      StrLCopy(Buffer, Text, BufSize - 1);
      Result := StrLen(Buffer);
    finally GlobalUnlock(Data); end;
  finally Close; end;
end;
procedure TClipboard.SetTextBuf(Buffer: PChar);
var Data: THandle; Size: LongInt;
begin
  Size := StrLen(Buffer) + 1;
  Data := GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE, Size);
  if Data = 0 then raise EClipboardError.Create('Out of clipboard memory');
  Move(Buffer^, GlobalLock(Data)^, Size);
  GlobalUnlock(Data);
  try SetAsHandle(CF_TEXT, Data);
  except GlobalFree(Data); raise; end;
end;
function TClipboard.GetAsText: string;
var Buffer: array[0..255] of Char;
begin
  GetTextBuf(Buffer, SizeOf(Buffer));
  Result := StrPas(Buffer);
end;
procedure TClipboard.SetAsText(const Value: string);
var Buffer: array[0..255] of Char;
begin
  SetTextBuf(StrPCopy(Buffer, Value));
end;
function TClipboard.GetFormatCount: Integer;
begin
  Result := CountClipboardFormats;
end;
function TClipboard.GetFormat(Index: Integer): Word;
begin
  Open;
  try
    Result := EnumClipboardFormats(0);
    while (Index > 0) and (Result <> 0) do
    begin
      Result := EnumClipboardFormats(Result);
      Dec(Index);
    end;
  finally Close; end;
end;
initialization
finalization
  FClipboard.Free;
end.
