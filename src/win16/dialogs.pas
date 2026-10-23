{ SPDX-License-Identifier: GPL-2.0-or-later
  Initial Dialogs subset: Delphi 1 style message and input dialogs built from
  the native form, label, edit and button controls. Captions are resolved
  through the optional form-text provider. Common dialogs (TOpenDialog,
  TFontDialog, TColorDialog) are not provided yet and must fail to compile. }
unit Dialogs;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Dialogs subset requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Controls, Forms, Buttons;
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
implementation
uses SysUtils, WinProcs, Graphics, native_application, native_label, native_button, native_edit, form_text;
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
  Form.Canvas.Font.Name := 'MS Sans Serif'; Form.Canvas.Font.Height := -11;
  Form.Canvas.Font.Style := []; Form.Canvas.Font.Color := clBlack;
end;
function AddButton(Form: TForm; const Caption: string; X, Y: Integer;
  ModalCode: TModalResult): TButton;
begin
  Result := TButton.Create(Form); Result.Parent := Form;
  Result.SetBounds(X, Y, MsgDlgBtnSize.X, MsgDlgBtnSize.Y);
  Result.Font.Assign(Form.Canvas.Font); Result.Caption := Caption;
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
      Icon.Color := Form.Color; Icon.SetBounds(Margin, Margin, IconSize, IconSize);
      TextLeft := Margin + IconSize + Margin;
    end;
    Text := TLabel.Create(Form); Text.Parent := Form;
    Text.Font.Assign(Form.Canvas.Font); Text.WordWrap := True; Text.ShowAccelChar := False;
    Text.Color := Form.Color;
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
    Prompt.Font.Assign(Form.Canvas.Font); Prompt.Color := Form.Color;
    Prompt.SetBounds(Margin, Margin, EditWidth, 13); Prompt.Caption := APrompt;
    Edit := TEdit.Create(Form); Edit.Parent := Form;
    Edit.SetBounds(Margin, Margin + 18, EditWidth, 23);
    Edit.Font.Assign(Form.Canvas.Font); Edit.MaxLength := 255; Edit.Text := Value;
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
finalization
  HelpDispatcher.Free; HelpDispatcher := nil;
end.
