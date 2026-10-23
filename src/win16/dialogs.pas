{ SPDX-License-Identifier: GPL-2.0-or-later
  Initial Dialogs subset: Delphi 1 style message and input dialogs built from
  the native form, label, edit and button controls. Captions are resolved
  through the optional form-text provider. The open, save, color and font
  common dialogs run COMMDLG.DLL without a hook: OnApply, help buttons,
  Ctl3D, the combo-box file edit and printer fonts are not provided. }
unit Dialogs;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Dialogs subset requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, Graphics, Controls, Forms, Buttons;
type
  TMsgDlgType = (mtWarning, mtError, mtInformation, mtConfirmation, mtCustom);
  TMsgDlgBtn = (mbYes, mbNo, mbOK, mbCancel, mbAbort, mbRetry, mbIgnore, mbAll, mbHelp);
  TMsgDlgButtons = set of TMsgDlgBtn;
const
  mbYesNoCancel = [mbYes, mbNo, mbCancel];
  mbOKCancel = [mbOK, mbCancel];
  mbAbortRetryIgnore = [mbAbort, mbRetry, mbIgnore];
{ The caller owns the returned, not yet shown form. }
function CreateMessageDialog(const Msg: string; AType: TMsgDlgType;
  AButtons: TMsgDlgButtons): TForm;
function MessageDlg(const Msg: string; AType: TMsgDlgType;
  AButtons: TMsgDlgButtons; HelpCtx: LongInt): Word;
procedure ShowMessage(const Msg: string);
function InputQuery(const ACaption, APrompt: string; var Value: string): Boolean;
function InputBox(const ACaption, APrompt, ADefault: string): string;
const
  { Delphi 1 defaults. The buttons are native USER buttons, so the style and
    glyph switches are kept for source compatibility only; the size is used. }
  MsgDlgButtonStyle: TButtonStyle = bsAutoDetect;
  MsgDlgGlyphs: Boolean = True;
  MsgDlgBtnSize: TPoint = (X: 77; Y: 27);
type
  TCommonDialog = class(TComponent)
  private
    FCtl3D: Boolean;
    FHelpContext: THelpContext;
  protected
    { The active window of the task, disabled while the dialog runs. }
    function OwnerWindow: HWND;
  public
    constructor Create(AOwner: TComponent); override;
  published
    { Kept for DFM compatibility; dialogs use the system look. }
    property Ctl3D: Boolean read FCtl3D write FCtl3D default True;
    property HelpContext: THelpContext read FHelpContext write FHelpContext default 0;
  end;
  TOpenOption = (ofReadOnly, ofOverwritePrompt, ofHideReadOnly,
    ofNoChangeDir, ofShowHelp, ofNoValidate, ofAllowMultiSelect,
    ofExtensionDifferent, ofPathMustExist, ofFileMustExist, ofCreatePrompt,
    ofShareAware, ofNoReadOnlyReturn, ofNoTestFileCreate);
  TOpenOptions = set of TOpenOption;
  TFileExt = string[3];
  TFileEditStyle = (fsEdit, fsComboBox);
  TOpenDialog = class(TCommonDialog)
  private
    FFiles, FHistoryList: TStrings;
    FDefaultExt: TFileExt;
    FFileEditStyle: TFileEditStyle;
    FFileName: TFileName;
    FFilter: string;
    FFilterIndex: Integer;
    FInitialDir: string;
    FOptions: TOpenOptions;
    FTitle: string;
    procedure SetHistoryList(Value: TStrings);
  protected
    function Run(Save: Boolean): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: Boolean; virtual;
    property Files: TStrings read FFiles;
  published
    property DefaultExt: TFileExt read FDefaultExt write FDefaultExt;
    { fsComboBox raises in Execute: it needs Delphi's dialog template. }
    property FileEditStyle: TFileEditStyle read FFileEditStyle write FFileEditStyle default fsEdit;
    property FileName: TFileName read FFileName write FFileName;
    property Filter: string read FFilter write FFilter;
    property FilterIndex: Integer read FFilterIndex write FFilterIndex default 1;
    property InitialDir: string read FInitialDir write FInitialDir;
    property HistoryList: TStrings read FHistoryList write SetHistoryList;
    property Options: TOpenOptions read FOptions write FOptions default [];
    property Title: string read FTitle write FTitle;
  end;
  TSaveDialog = class(TOpenDialog)
  public
    function Execute: Boolean; override;
  end;
  TColorDialogOption = (cdFullOpen, cdPreventFullOpen, cdShowHelp);
  TColorDialogOptions = set of TColorDialogOption;
const
  MaxCustomColors = 16;
type
  TCustomColors = array[0..MaxCustomColors - 1] of LongInt;
  TColorDialog = class(TCommonDialog)
  private
    FColor: TColor;
    FCustomColors: TStrings;
    FOptions: TColorDialogOptions;
    procedure SetCustomColors(Value: TStrings);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: Boolean;
  published
    property Color: TColor read FColor write FColor default clBlack;
    property Ctl3D default False;
    { ColorA=RRGGBB .. ColorP=RRGGBB, as Delphi stores them. }
    property CustomColors: TStrings read FCustomColors write SetCustomColors;
    property Options: TColorDialogOptions read FOptions write FOptions default [];
  end;
  TFontDialogOption = (fdAnsiOnly, fdTrueTypeOnly, fdEffects, fdFixedPitchOnly,
    fdForceFontExist, fdNoFaceSel, fdNoOEMFonts, fdNoSimulations, fdNoSizeSel,
    fdNoStyleSel,  fdNoVectorFonts, fdShowHelp, fdWysiwyg, fdLimitSize,
    fdScalableOnly);
  TFontDialogOptions = set of TFontDialogOption;
  TFontDialogDevice = (fdScreen, fdPrinter, fdBoth);
  { Name, height, style and color are taken over; there is no printer. }
  TFontDialog = class(TCommonDialog)
  private
    FFont: TFont;
    FDevice: TFontDialogDevice;
    FMinFontSize, FMaxFontSize: Integer;
    FOptions: TFontDialogOptions;
    procedure SetFont(Value: TFont);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: Boolean;
  published
    property Font: TFont read FFont write SetFont;
    property Device: TFontDialogDevice read FDevice write FDevice default fdScreen;
    property MinFontSize: Integer read FMinFontSize write FMinFontSize;
    property MaxFontSize: Integer read FMaxFontSize write FMaxFontSize;
    property Options: TFontDialogOptions read FOptions write FOptions default [fdEffects];
  end;
implementation
uses WinProcs, CommDlg, native_application, native_label, native_button, native_edit, form_text;
const
  DialogStyle = WS_POPUP or WS_CAPTION or WS_DLGFRAME or WS_SYSMENU;
  Margin = 12; IconSize = 32; ButtonGap = 6;
  { Keys double as English defaults. }
  TitleKeys: array[TMsgDlgType] of string[11] =
    ('Warning', 'Error', 'Information', 'Confirm', '');
  ButtonKeys: array[TMsgDlgBtn] of string[6] =
    ('Yes', 'No', 'OK', 'Cancel', 'Abort', 'Retry', 'Ignore', 'All', 'Help');
  ButtonTexts: array[TMsgDlgBtn] of string[7] =
    ('&Yes', '&No', 'OK', 'Cancel', '&Abort', '&Retry', '&Ignore', '&All', '&Help');
  ButtonResults: array[TMsgDlgBtn] of TModalResult =
    (mrYes, mrNo, mrOk, mrCancel, mrAbort, mrRetry, mrIgnore, mrAll, mrNone);
type
  { No TForm subclass: its VMT alone costs 352 bytes of the shared DGROUP. }
  TMessageIcon = class(TGraphicControl)
  private
    FIcon: HICON;
  protected
    procedure Paint; override;
  end;
  THelpDispatcher = class
    procedure Click(Sender: TObject);
  end;
var HelpDispatcher: THelpDispatcher;
procedure THelpDispatcher.Click(Sender: TObject);
begin
  Application.HelpContext(TCustomControl(TComponent(Sender).Owner).HelpContext);
end;
procedure FinishForm(Form: TForm; AWidth, AHeight: Integer);
var Area: TRect;
begin
  Area := Graphics.Rect(0, 0, AWidth, AHeight);
  AdjustWindowRect(Area, DialogStyle, False);
  Form.SetBounds((GetSystemMetrics(SM_CXSCREEN) - (Area.Right - Area.Left)) div 2,
    (GetSystemMetrics(SM_CYSCREEN) - (Area.Bottom - Area.Top)) div 2,
    Area.Right - Area.Left, Area.Bottom - Area.Top);
  { An existing HWND keeps ShowModal from creating a resizable frame. }
  Form.CreateHandle(0, Form.Caption, DialogStyle or WS_CLIPCHILDREN or WS_CLIPSIBLINGS,
    Form.Left, Form.Top, Form.Width, Form.Height);
end;
procedure TMessageIcon.Paint;
begin
  if (FIcon <> 0) and (Canvas.Handle <> 0) then DrawIcon(Canvas.Handle, 0, 0, FIcon);
end;
function DialogText(const Key, Default: string): string;
begin
  { Cancel shares the generated dialogs' standard-button translation. }
  if Key = 'Cancel' then Result := FormText('TStandardButtons', 'Cancel', 'Caption', Default)
  else Result := FormText('TMessageForm', Key, 'Caption', Default);
end;
function MeasureText(Font: TFont; const Text: string; MaxWidth: Integer): TRect;
var Display: HDC; Previous: HFONT; Buffer: array[0..255] of Char;
begin
  Result := Graphics.Rect(0, 0, MaxWidth, 0);
  if Text = '' then Exit;
  StrPCopy(Buffer, Text);
  Display := GetDC(0);
  if Display = 0 then raise ENativeApplicationError.Create('Cannot acquire screen DC');
  try
    Previous := SelectObject(Display, Font.Handle);
    try
      DrawText(Display, Buffer, Length(Text), Result,
        DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX or DT_EXPANDTABS);
    finally SelectObject(Display, Previous); end;
  finally ReleaseDC(0, Display); end;
end;
procedure PrepareForm(Form: TForm; const Caption: string);
begin
  Form.Caption := Caption;
  { Children pick this up through ParentFont. }
  Form.Font.Name := 'MS Sans Serif'; Form.Font.Height := -11;
  Form.Font.Style := []; Form.Font.Color := clBlack;
end;
function AddButton(Form: TForm; const Caption: string; X, Y: Integer;
  ModalCode: TModalResult): TButton;
begin
  Result := TButton.Create(Form); Result.Parent := Form;
  Result.SetBounds(X, Y, MsgDlgBtnSize.X, MsgDlgBtnSize.Y);
  Result.Caption := Caption;
  Result.ModalResult := ModalCode;
end;
function CreateMessageDialog(const Msg: string; AType: TMsgDlgType;
  AButtons: TMsgDlgButtons): TForm;
const
  Icons: array[TMsgDlgType] of PChar =
    (IDI_EXCLAMATION, IDI_HAND, IDI_ASTERISK, IDI_QUESTION, nil);
var Form: TForm; Text: TLabel; Icon: TMessageIcon; Button: TButton;
  DefaultButton, CancelButton, B: TMsgDlgBtn; HasDefault: Boolean; TextArea: TRect;
  Count, TextLeft, TextWidth, ButtonsWidth, ClientWidth, ButtonTop, X, Order: Integer;
begin
  if AButtons = [] then raise ENativeApplicationError.Create('Message dialog needs a button');
  Form := TForm.Create(Application);
  try
    if AType = mtCustom then PrepareForm(Form, Application.Title)
    else PrepareForm(Form, DialogText(TitleKeys[AType], TitleKeys[AType]));
    TextLeft := Margin;
    if Icons[AType] <> nil then
    begin
      Icon := TMessageIcon.Create(Form); Icon.Parent := Form;
      Icon.FIcon := LoadIcon(0, Icons[AType]);
      Icon.SetBounds(Margin, Margin, IconSize, IconSize);
      TextLeft := Margin + IconSize + Margin;
    end;
    Text := TLabel.Create(Form); Text.Parent := Form;
    Text.WordWrap := True; Text.ShowAccelChar := False;
    TextArea := MeasureText(Text.Font, Msg, GetSystemMetrics(SM_CXSCREEN) div 2);
    TextWidth := TextArea.Right - TextArea.Left;
    Text.SetBounds(TextLeft, Margin, TextWidth, TextArea.Bottom - TextArea.Top);
    Text.Caption := Msg;
    Count := 0;
    for B := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
      if B in AButtons then Inc(Count);
    ButtonsWidth := Count * MsgDlgBtnSize.X + (Count - 1) * ButtonGap;
    ClientWidth := TextLeft + TextWidth + Margin;
    if ButtonsWidth + 2 * Margin > ClientWidth then ClientWidth := ButtonsWidth + 2 * Margin;
    ButtonTop := Margin + TextArea.Bottom - TextArea.Top;
    if (Icons[AType] <> nil) and (ButtonTop < Margin + IconSize) then ButtonTop := Margin + IconSize;
    Inc(ButtonTop, Margin);
    HasDefault := True;
    if mbOK in AButtons then DefaultButton := mbOK
    else if mbYes in AButtons then DefaultButton := mbYes
    else begin DefaultButton := mbOK; HasDefault := False; end;
    if mbCancel in AButtons then CancelButton := mbCancel
    else if mbNo in AButtons then CancelButton := mbNo
    else CancelButton := mbOK;
    X := (ClientWidth - ButtonsWidth) div 2; Order := 0;
    for B := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
      if B in AButtons then
      begin
        Button := AddButton(Form, DialogText(ButtonKeys[B], ButtonTexts[B]), X, ButtonTop,
          ButtonResults[B]);
        Button.Name := ButtonKeys[B]; Button.TabOrder := Order;
        if HasDefault and (B = DefaultButton) then Button.Default := True;
        if B = CancelButton then Button.Cancel := True;
        if B = mbHelp then
        begin
          if HelpDispatcher = nil then HelpDispatcher := THelpDispatcher.Create;
          Button.OnClick := HelpDispatcher.Click;
        end;
        { Without OK/Yes, focus starts on the first button, as in Delphi. }
        if (HasDefault and (B = DefaultButton)) or (not HasDefault and (Order = 0)) then
          Form.InitialControl := Button;
        Inc(X, MsgDlgBtnSize.X + ButtonGap); Inc(Order);
      end;
    FinishForm(Form, ClientWidth, ButtonTop + MsgDlgBtnSize.Y + Margin);
  except Form.Free; raise; end;
  Result := Form;
end;
function MessageDlg(const Msg: string; AType: TMsgDlgType;
  AButtons: TMsgDlgButtons; HelpCtx: LongInt): Word;
var Form: TForm;
begin
  Form := CreateMessageDialog(Msg, AType, AButtons);
  try
    Form.HelpContext := HelpCtx;
    Result := Form.ShowModal;
  finally Form.Free; end;
end;
procedure ShowMessage(const Msg: string);
begin
  MessageDlg(Msg, mtCustom, [mbOK], 0);
end;
function InputQuery(const ACaption, APrompt: string; var Value: string): Boolean;
const FormWidth = 270; EditWidth = 246;
var Form: TForm; Prompt: TLabel; Edit: TEdit; Button: TButton; ButtonTop: Integer;
begin
  Result := False;
  Form := TForm.Create(Application);
  try
    PrepareForm(Form, ACaption);
    Prompt := TLabel.Create(Form); Prompt.Parent := Form;
    Prompt.SetBounds(Margin, Margin, EditWidth, 13); Prompt.Caption := APrompt;
    Edit := TEdit.Create(Form); Edit.Parent := Form;
    Edit.SetBounds(Margin, Margin + 18, EditWidth, 23);
    Edit.MaxLength := 255; Edit.Text := Value;
    Edit.TabOrder := 0; Prompt.FocusControl := Edit;
    ButtonTop := Margin + 18 + 23 + Margin;
    Button := AddButton(Form, DialogText('OK', 'OK'),
      (FormWidth - 2 * MsgDlgBtnSize.X - ButtonGap) div 2, ButtonTop, mrOk);
    Button.Default := True; Button.TabOrder := 1;
    Button := AddButton(Form, DialogText('Cancel', 'Cancel'),
      (FormWidth + ButtonGap) div 2, ButtonTop, mrCancel);
    Button.Cancel := True; Button.TabOrder := 2;
    Form.InitialControl := Edit;
    FinishForm(Form, FormWidth, ButtonTop + MsgDlgBtnSize.Y + Margin);
    Edit.SelectAll;
    if Form.ShowModal = mrOk then begin Value := Edit.Text; Result := True; end;
  finally Form.Free; end;
end;
function InputBox(const ACaption, APrompt, ADefault: string): string;
begin
  Result := ADefault;
  InputQuery(ACaption, APrompt, Result);
end;
{ Common dialogs }
procedure CheckDialogError;
var Code: LongInt;
begin
  Code := CommDlgExtendedError;
  if Code <> 0 then raise EInvalidOperation.CreateFmt('Common dialog error %d', [Code]);
end;
constructor TCommonDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCtl3D := True;
end;
function TCommonDialog.OwnerWindow: HWND;
begin
  Result := GetActiveWindow;
  if (Result = 0) and (Application <> nil) then Result := Application.Handle;
end;
constructor TOpenDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFiles := TStringList.Create;
  FHistoryList := TStringList.Create;
  FFilterIndex := 1;
end;
destructor TOpenDialog.Destroy;
begin
  FFiles.Free; FHistoryList.Free;
  inherited Destroy;
end;
procedure TOpenDialog.SetHistoryList(Value: TStrings);
begin FHistoryList.Assign(Value); end;
const
  OpenFlags: array[TOpenOption] of LongInt = (OFN_READONLY, OFN_OVERWRITEPROMPT,
    OFN_HIDEREADONLY, OFN_NOCHANGEDIR, OFN_SHOWHELP, OFN_NOVALIDATE, OFN_ALLOWMULTISELECT,
    OFN_EXTENSIONDIFFERENT, OFN_PATHMUSTEXIST, OFN_FILEMUSTEXIST, OFN_CREATEPROMPT,
    OFN_SHAREAWARE, OFN_NOREADONLYRETURN, OFN_NOTESTFILECREATE);
  { Room for a multiple selection: a directory and many 8.3 names. }
  MultiFileSize = 2048;
function TOpenDialog.Run(Save: Boolean): Boolean;
var Info: TOpenFilename; Option: TOpenOption; FilterText: string;
  FilterBuf: array[0..256] of Char; DirBuf, TitleBuf: array[0..79] of Char;
  ExtBuf: array[0..3] of Char; Buffer: PChar; Size, I: Integer; Dir, Name: string; P: PChar;
begin
  if FFileEditStyle <> fsEdit then raise EInvalidOperation.Create('Combo-box file edits are not supported');
  FillChar(Info, SizeOf(Info), 0);
  Info.lStructSize := SizeOf(Info);
  Info.hwndOwner := OwnerWindow;
  for Option := Low(TOpenOption) to High(TOpenOption) do
    if Option in FOptions then Info.Flags := Info.Flags or OpenFlags[Option];
  { The help button would need a hook. }
  Info.Flags := Info.Flags and not OFN_SHOWHELP;
  if FFilter <> '' then
  begin
    { 'Text|*.TXT|All|*.*' becomes NUL-separated pairs ending in two NULs. }
    FilterText := FFilter + '|';
    for I := 1 to Length(FilterText) do
      if FilterText[I] = '|' then FilterText[I] := #0;
    FillChar(FilterBuf, SizeOf(FilterBuf), 0);
    Move(FilterText[1], FilterBuf, Length(FilterText));
    Info.lpstrFilter := FilterBuf;
    Info.nFilterIndex := FFilterIndex;
  end;
  if FInitialDir <> '' then Info.lpstrInitialDir := StrPLCopy(DirBuf, FInitialDir, High(DirBuf));
  if FTitle <> '' then Info.lpstrTitle := StrPLCopy(TitleBuf, FTitle, High(TitleBuf));
  if FDefaultExt <> '' then Info.lpstrDefExt := StrPCopy(ExtBuf, FDefaultExt);
  if ofAllowMultiSelect in FOptions then Size := MultiFileSize else Size := 256;
  GetMem(Buffer, Size);
  try
    FillChar(Buffer^, Size, 0);
    StrPLCopy(Buffer, FFileName, Size - 1);
    Info.lpstrFile := Buffer;
    Info.nMaxFile := Size;
    if Save then Result := GetSaveFileName(Info) else Result := GetOpenFileName(Info);
    if not Result then begin CheckDialogError; Exit; end;
    FFiles.Clear;
    if ofAllowMultiSelect in FOptions then
    begin
      { USER 3.1 returns "dir name name ..." for several files. }
      P := Buffer; Dir := '';
      while P^ <> #0 do
      begin
        Name := '';
        while (P^ <> ' ') and (P^ <> #0) do begin Name := Name + P^; Inc(P); end;
        while P^ = ' ' do Inc(P);
        if Dir = '' then Dir := Name
        else if Dir[Length(Dir)] = '\' then FFiles.Add(Dir + Name)
        else FFiles.Add(Dir + '\' + Name);
      end;
      if FFiles.Count = 0 then FFiles.Add(Dir);
      FFileName := FFiles[0];
    end
    else
    begin
      FFileName := StrPas(Buffer);
      FFiles.Add(FFileName);
    end;
    FFilterIndex := Info.nFilterIndex;
    if Info.Flags and OFN_READONLY <> 0 then Include(FOptions, ofReadOnly)
    else Exclude(FOptions, ofReadOnly);
    if Info.Flags and OFN_EXTENSIONDIFFERENT <> 0 then Include(FOptions, ofExtensionDifferent)
    else Exclude(FOptions, ofExtensionDifferent);
  finally FreeMem(Buffer, Size); end;
end;
function TOpenDialog.Execute: Boolean;
begin Result := Run(False); end;
function TSaveDialog.Execute: Boolean;
begin Result := Run(True); end;
constructor TColorDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Ctl3D := False;
  FCustomColors := TStringList.Create;
end;
destructor TColorDialog.Destroy;
begin
  FCustomColors.Free;
  inherited Destroy;
end;
procedure TColorDialog.SetCustomColors(Value: TStrings);
begin FCustomColors.Assign(Value); end;
function TColorDialog.Execute: Boolean;
const ColorFlags: array[TColorDialogOption] of LongInt = (CC_FULLOPEN, CC_PREVENTFULLOPEN, CC_SHOWHELP);
var Info: TChooseColor; Option: TColorDialogOption; Colors: TCustomColors; I: Integer; Text: string;
begin
  for I := 0 to MaxCustomColors - 1 do
  begin
    Text := FCustomColors.Values['Color' + Chr(Ord('A') + I)];
    if Text = '' then Colors[I] := $FFFFFF else Colors[I] := StrToInt('$' + Text);
  end;
  FillChar(Info, SizeOf(Info), 0);
  Info.lStructSize := SizeOf(Info);
  Info.hwndOwner := OwnerWindow;
  Info.rgbResult := ColorToRGB(FColor);
  Info.lpCustColors := @Colors;
  Info.Flags := CC_RGBINIT;
  for Option := Low(TColorDialogOption) to High(TColorDialogOption) do
    if Option in FOptions then Info.Flags := Info.Flags or ColorFlags[Option];
  Info.Flags := Info.Flags and not CC_SHOWHELP;
  Result := ChooseColor(Info);
  if not Result then begin CheckDialogError; Exit; end;
  FColor := TColor(Info.rgbResult);
  FCustomColors.Clear;
  for I := 0 to MaxCustomColors - 1 do
    FCustomColors.Add('Color' + Chr(Ord('A') + I) + '=' + IntToHex(Colors[I], 6));
end;
constructor TFontDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFont := TFont.Create;
  FOptions := [fdEffects];
end;
destructor TFontDialog.Destroy;
begin
  FFont.Free;
  inherited Destroy;
end;
procedure TFontDialog.SetFont(Value: TFont);
begin FFont.Assign(Value); end;
function TFontDialog.Execute: Boolean;
const FontFlags: array[TFontDialogOption] of LongInt = (CF_ANSIONLY, CF_TTONLY, CF_EFFECTS,
  CF_FIXEDPITCHONLY, CF_FORCEFONTEXIST, CF_NOFACESEL, CF_NOOEMFONTS, CF_NOSIMULATIONS, CF_NOSIZESEL,
  CF_NOSTYLESEL, CF_NOVECTORFONTS, CF_SHOWHELP, CF_WYSIWYG, CF_LIMITSIZE, CF_SCALABLEONLY);
var Info: TChooseFont; LogFont: TLogFont; Option: TFontDialogOption; Style: TFontStyles;
begin
  if (FDevice <> fdScreen) or (fdWysiwyg in FOptions) then
    raise EInvalidOperation.Create('Printer fonts are not supported');
  FillChar(LogFont, SizeOf(LogFont), 0);
  LogFont.lfHeight := FFont.Height;
  if fsBold in FFont.Style then LogFont.lfWeight := FW_BOLD else LogFont.lfWeight := FW_NORMAL;
  LogFont.lfItalic := Ord(fsItalic in FFont.Style);
  LogFont.lfUnderline := Ord(fsUnderline in FFont.Style);
  LogFont.lfStrikeOut := Ord(fsStrikeOut in FFont.Style);
  StrPLCopy(LogFont.lfFaceName, FFont.Name, LF_FACESIZE - 1);
  FillChar(Info, SizeOf(Info), 0);
  Info.lStructSize := SizeOf(Info);
  Info.hwndOwner := OwnerWindow;
  Info.lpLogFont := @LogFont;
  Info.rgbColors := ColorToRGB(FFont.Color);
  Info.Flags := CF_SCREENFONTS or CF_INITTOLOGFONTSTRUCT;
  for Option := Low(TFontDialogOption) to High(TFontDialogOption) do
    if Option in FOptions then Info.Flags := Info.Flags or FontFlags[Option];
  Info.Flags := Info.Flags and not CF_SHOWHELP;
  { As in Delphi, a size range limits the sizes offered. }
  if (FMinFontSize <> 0) or (FMaxFontSize <> 0) then Info.Flags := Info.Flags or CF_LIMITSIZE;
  Info.nSizeMin := FMinFontSize;
  Info.nSizeMax := FMaxFontSize;
  Result := ChooseFont(Info);
  if not Result then begin CheckDialogError; Exit; end;
  Style := [];
  if LogFont.lfWeight >= FW_BOLD then Include(Style, fsBold);
  if LogFont.lfItalic <> 0 then Include(Style, fsItalic);
  if LogFont.lfUnderline <> 0 then Include(Style, fsUnderline);
  if LogFont.lfStrikeOut <> 0 then Include(Style, fsStrikeOut);
  FFont.Name := StrPas(LogFont.lfFaceName);
  FFont.Height := LogFont.lfHeight;
  FFont.Style := Style;
  FFont.Color := TColor(Info.rgbColors);
end;
finalization
  HelpDispatcher.Free; HelpDispatcher := nil;
end.
