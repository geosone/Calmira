{*********************************************************}
{                                                         }
{    Calmira System Library 3.1                           }
{    by Erwin Dokter,                                     }
{    released into the public domain july 2000            }
{                                                         }
{*********************************************************}

unit Registry;

{ TRegistry is a simple wrapper object around ShellAPI's Registry
  calls, to make the registration database easier to access, much
  like TIniFile or TRegistry in Delphi 2.

  OpenKey() or CreateKey() creates a key handle which is stored
  in the CurrentKey property. The CurentKeyStr property contains
  a string of the currently open key. CloseKey will flush changes
  to the registry. Opening a key will automatically close the
  preious key.

  Calling OpenKey(), CreateKey() and CloseKey is not mandatory,
  however it will speed up access when writing to the registry
  or enumerating keys. Otherwise, they are not needed.

  EnumKey() opens the key automatically if OpenKey() has not been
  called in advance, or a different key then the current key is
  specified. }

interface

uses SysUtils, ShellAPI, Classes;

type
  ERegistryException = class(Exception);

  TRegistry = class(TObject)
  private
    { Private declarations }
    FRootKey: HKey;
    FCurrentKey: HKey;
    FCurrentKeyStr: string;
  public
    { Public Declarations }
    ShowException: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure CloseKey;
    function OpenKey(const Key: string): Boolean;
    function CreateKey(const Key: string): Boolean;
    function DeleteKey(const Key: string): Boolean;
    function EnumKey(const Key: string; Index: Longint;
      var SubKey: string): Boolean;
    function ReadString(const Key: string): string;
    function ReadInteger(const Key: string): Integer;
    function ReadBool(const Key: string): Boolean;
    procedure WriteString(const Key, Value: string);
    procedure WriteInteger(const Key: string; Value: Integer);
    procedure WriteBool(const Key: string; Value: Boolean);
    property RootKey: HKey read FRootKey;
    property CurrentKey: HKey read FCurrentKey;
    property CurrentKeyStr: string read FCurrentKeyStr;
  end;

const
  SRegWriteError = 'Error writing to registry';

implementation

constructor TRegistry.Create;
begin
  FRootKey := HKEY_CLASSES_ROOT;
  FCurrentKey := 0;
  FCurrentKeyStr := '';
  ShowException := False;
end;

destructor TRegistry.Destroy;
begin
  CloseKey;
  inherited Destroy;
end;

procedure TRegistry.CloseKey;
begin
  if CurrentKey <> 0 then
  begin
    RegCloseKey(CurrentKey);
    FCurrentKey := 0;
    FCurrentKeyStr := '';
  end;
end;

function TRegistry.OpenKey(const Key: string): Boolean;
var
  buf: array[0..255] of Char;
begin
  If CurrentKey <> 0 then CloseKey;
  Result := RegOpenKey(RootKey, StrPCopy(buf, Key), FCurrentKey) = ERROR_SUCCESS;
  if Result then FCurrentKeyStr := Key;
end;

function TRegistry.CreateKey(const Key: string): Boolean;
var
  buf: array[0..255] of Char;
begin
  If CurrentKey <> 0 then CloseKey;
  Result := RegCreateKey(RootKey, StrPCopy(buf, Key), FCurrentKey) = ERROR_SUCCESS;
  if Result then FCurrentKeyStr := Key
  else if ShowException then
    raise ERegistryException.Create(SRegWriteError);
end;

function TRegistry.DeleteKey(const Key: string): Boolean;
var
  buf: array[0..255] of Char;
begin
  if CurrentKeyStr = Key then CloseKey;
  Result := RegDeleteKey(RootKey, StrPCopy(buf, Key)) = ERROR_SUCCESS;
  if (not Result) and ShowException then
    raise ERegistryException.Create(SRegWriteError);
end;

function TRegistry.EnumKey(const Key: string; Index: Longint;
  var SubKey: string): Boolean;
var
  cb: Longint;
  buf: array[0..255] of Char;
begin
  SubKey := '';
  Result := False;
  if (CurrentKey = 0) or (CurrentKeyStr <> Key) then
    if not OpenKey(Key) then Exit;
  cb := SizeOf(buf) - 1;
  Result := RegEnumKey(CurrentKey, Index, buf, cb) = ERROR_SUCCESS;
  if Result then SubKey := StrPas(buf);
end;

function TRegistry.ReadString(const Key: string): string;
var
  cb: Longint;
  keybuf, valbuf: array[0..255] of Char;
begin
  Result := '';
  cb := SizeOf(valbuf) - 1;
  if RegQueryValue(RootKey, StrPCopy(keybuf, Key), valbuf, cb) = ERROR_SUCCESS then
    Result := StrPas(valbuf);
end;

function TRegistry.ReadInteger(const Key: string): Integer;
var
  IntStr: string;
begin
  IntStr := ReadString(Key);
  if (Length(IntStr) > 2) and (IntStr[1] = '0') and
    ((IntStr[2] = 'X') or (IntStr[2] = 'x')) then
      IntStr := '$' + Copy(IntStr, 3, Maxint);
  Result := StrToIntDef(IntStr, 0);
end;

function TRegistry.ReadBool(const Key: string): Boolean;
begin
  Result := ReadInteger(Key) <> 0;
end;

procedure TRegistry.WriteString(const Key, Value: string);
var
  cb: Longint;
  keybuf, valbuf: array[0..255] of Char;
begin
  cb := Length(Value) + 1;
  if (CurrentKey <> 0) and (CurrentKeyStr = Key) then
  begin
    if (RegSetValue(CurrentKey, nil, REG_SZ,
      StrPCopy(valbuf, Value), cb) <> ERROR_SUCCESS)
      and ShowException then
        raise ERegistryException.Create(SRegWriteError);
  end
  else
  begin
    if (RegSetValue(RootKey, StrPCopy(keybuf, Key), REG_SZ,
      StrPCopy(valbuf, Value), cb) <> ERROR_SUCCESS)
      and ShowException then
        raise ERegistryException.Create(SRegWriteError);
  end;
end;

procedure TRegistry.WriteInteger(const Key: string; Value: Integer);
begin
  WriteString(Key, IntToStr(Value));
end;

procedure TRegistry.WriteBool(const Key: string; Value: Boolean);
const
  Values: array[Boolean] of string = ('0', '1');
begin
  WriteString(Key, Values[Value]);
end;

end.
