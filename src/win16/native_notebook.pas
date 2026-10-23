{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 TNotebook/TPage: a container showing one page at a time. Pages are
  created through Pages.Add and fill the notebook's client area; Pages.Objects
  holds the TPage. An inactive page may lose its handle (Calmira frees them to
  save USER heap); it is recreated with its children when shown again. }
unit native_notebook;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This notebook requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Controls;
type
  TNotebook = class;
  TPage = class(TCustomControl)
  private
    FCaption: string;
    FNotebook: TNotebook;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption: string read FCaption write FCaption;
  end;
  TPageStrings = class(TStrings)
  private
    FNotebook: TNotebook;
  protected
    function Get(Index: Integer): AnsiString; override;
    function GetCount: Integer; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: AnsiString); override;
  public
    function Add(const S: AnsiString): Integer; override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: AnsiString); override;
    procedure Move(CurIndex, NewIndex: Integer); override;
  end;
  TNotebook = class(TCustomControl)
  private
    FPages: TList;
    FAccess: TPageStrings;
    FPageIndex: Integer;
    FOnPageChanged: TNotifyEvent;
    function GetPages: TStrings;
    procedure SetPages(Value: TStrings);
    procedure SetPageIndex(Value: Integer);
    function GetActivePage: string;
    procedure SetActivePage(const Value: string);
    function GetPage(Index: Integer): TPage;
    procedure FitPage(Page: TPage);
    procedure ShowPage(Page: TPage);
    procedure WMSize(var M: TMessage); message WM_SIZE;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
  published
    property ActivePage: string read GetActivePage write SetActivePage;
    property PageIndex: Integer read FPageIndex write SetPageIndex default 0;
    property Pages: TStrings read GetPages write SetPages;
    property OnPageChanged: TNotifyEvent read FOnPageChanged write FOnPageChanged;
    property Enabled;
    property Visible;
    property TabStop;
    property TabOrder;
  end;
implementation
uses SysUtils, WinProcs, native_window;
procedure Fail(const Text: string);
begin raise ENativeWindowError.Create(Text); end;
{ TPage }
constructor TPage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Visible := False;
end;
{ TPageStrings }
function TPageStrings.Get(Index: Integer): AnsiString;
begin Result := FNotebook.GetPage(Index).Caption; end;
function TPageStrings.GetCount: Integer;
begin Result := FNotebook.FPages.Count; end;
function TPageStrings.GetObject(Index: Integer): TObject;
begin Result := FNotebook.GetPage(Index); end;
procedure TPageStrings.Put(Index: Integer; const S: AnsiString);
begin FNotebook.GetPage(Index).Caption := S; end;
function TPageStrings.Add(const S: AnsiString): Integer;
begin
  Result := Count;
  Insert(Result, S);
end;
procedure TPageStrings.Insert(Index: Integer; const S: AnsiString);
var Page: TPage;
begin
  if (Index < 0) or (Index > Count) then Fail('Notebook page index out of range');
  Page := TPage.Create(FNotebook);
  Page.FNotebook := FNotebook;
  Page.Caption := S;
  FNotebook.FPages.Insert(Index, Page);
  FNotebook.FitPage(Page);
  Page.Parent := FNotebook;
  if FNotebook.FPages.Count = 1 then
  begin
    FNotebook.FPageIndex := 0;
    FNotebook.ShowPage(Page);
  end
  else if Index <= FNotebook.FPageIndex then Inc(FNotebook.FPageIndex);
end;
procedure TPageStrings.Delete(Index: Integer);
var Page: TPage; WasActive: Boolean;
begin
  Page := FNotebook.GetPage(Index);
  WasActive := Index = FNotebook.FPageIndex;
  FNotebook.FPages.Delete(Index);
  Page.Free;
  if Index < FNotebook.FPageIndex then Dec(FNotebook.FPageIndex);
  if FNotebook.FPageIndex >= Count then FNotebook.FPageIndex := Count - 1;
  if FNotebook.FPageIndex < 0 then FNotebook.FPageIndex := 0;
  if WasActive and (Count > 0) then FNotebook.ShowPage(FNotebook.GetPage(FNotebook.FPageIndex));
end;
procedure TPageStrings.Clear;
begin
  while Count > 0 do Delete(Count - 1);
end;
procedure TPageStrings.Move(CurIndex, NewIndex: Integer);
var Active: TPage;
begin
  Active := nil;
  if Count > 0 then Active := FNotebook.GetPage(FNotebook.FPageIndex);
  FNotebook.FPages.Move(CurIndex, NewIndex);
  if Active <> nil then FNotebook.FPageIndex := FNotebook.FPages.IndexOf(Active);
end;
{ TNotebook }
constructor TNotebook.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPages := TList.Create;
  FAccess := TPageStrings.Create;
  FAccess.FNotebook := Self;
  SetBounds(0, 0, 150, 150);
  { Delphi 1 starts with one page named Default. }
  FAccess.Add('Default');
end;
destructor TNotebook.Destroy;
begin
  { Pages are owned (and freed) as components; only forget them here. }
  FPages.Clear;
  inherited Destroy;
  FAccess.Free;
  FPages.Free;
end;
function TNotebook.GetPage(Index: Integer): TPage;
begin
  if (Index < 0) or (Index >= FPages.Count) then Fail('Notebook page index out of range');
  Result := TPage(FPages[Index]);
end;
function TNotebook.GetPages: TStrings;
begin Result := FAccess; end;
procedure TNotebook.SetPages(Value: TStrings);
var I: Integer;
begin
  FAccess.Clear;
  for I := 0 to Value.Count - 1 do FAccess.Add(Value[I]);
end;
procedure TNotebook.FitPage(Page: TPage);
begin
  Page.SetBounds(0, 0, ClientWidth, ClientHeight);
end;
procedure TNotebook.ShowPage(Page: TPage);
var I: Integer;
begin
  FitPage(Page);
  if (Handle <> 0) and (Page.Handle = 0) then Page.CreateControl(Handle);
  Page.Visible := True;
  Page.BringToFront;
  for I := 0 to FPages.Count - 1 do
    if FPages[I] <> Page then TPage(FPages[I]).Visible := False;
end;
procedure TNotebook.SetPageIndex(Value: Integer);
begin
  if Value = FPageIndex then Exit;
  if (Value < 0) or (Value >= FPages.Count) then Fail('Notebook page index out of range');
  FPageIndex := Value;
  ShowPage(GetPage(Value));
  if Assigned(FOnPageChanged) then FOnPageChanged(Self);
end;
function TNotebook.GetActivePage: string;
begin
  if FPages.Count = 0 then Result := '' else Result := GetPage(FPageIndex).Caption;
end;
procedure TNotebook.SetActivePage(const Value: string);
var Index: Integer;
begin
  Index := FAccess.IndexOf(Value);
  if Index >= 0 then PageIndex := Index;
end;
procedure TNotebook.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
var I: Integer;
begin
  inherited CreateHandle(Parent, Caption, Style, X, Y, Width, Height);
  for I := 0 to FPages.Count - 1 do FitPage(TPage(FPages[I]));
end;
procedure TNotebook.WMSize(var M: TMessage);
var I: Integer;
begin
  inherited;
  for I := 0 to FPages.Count - 1 do FitPage(TPage(FPages[I]));
end;
end.
