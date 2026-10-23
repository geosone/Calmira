program PasswordLanguageTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Password, Controls, Locale,
  form_text, resource_text, form_catalog;
type TD = object
  Errors: Integer;
  Last: Word;
  Prefix: Char;
  Valid: Boolean;
  procedure Error(Sender: TObject; Ident: Word);
  function InvalidResource(Ident: Word; const DefaultText: string): string;
end;
var Dialog: TPasswordDlg; Catalog: TFormTextCatalog; Driver: TD; Failed: Boolean;
  PreviousForm: TFormTextProvider; PreviousResource: TResourceTextProvider;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure TD.Error(Sender: TObject; Ident: Word);
var Text: string;
begin
  Inc(Errors); Last := Ident; Text := LocalLoadStr(Ident);
  Valid := Valid and (Sender = Dialog) and (Length(Text) > 0);
  if Text <> '' then Valid := Valid and (Text[1] = Prefix);
end;
function TD.InvalidResource(Ident: Word; const DefaultText: string): string;
begin Result := 'a'#0'b'; end;
procedure FailedInitialization;
var Previous: TResourceTextProvider; Rejected: Boolean;
begin
  Dialog.Hide; Previous := SetResourceTextProvider(Driver.InvalidResource);
  try
    Rejected := False;
    try Dialog.InitNewUser; except on Exception do Rejected := True; end;
    Check(Rejected, 'invalid provider rejected');
  finally SetResourceTextProvider(Previous); end;
  Rejected := False;
  try Dialog.OKBtn.Click; except on Exception do Rejected := True; end;
  Check(Rejected and (Dialog.ModalResult = mrNone), 'partial initialization cannot accept');
end;
procedure NewUserChecks(const NewTitle, ChangeTitle, UserText, CancelText: string);
var Buffer: array[0..255] of Char;
begin
    Dialog.OnValidationError := Driver.Error; Dialog.InitNewUser;
    Check((Dialog.Caption = NewTitle) and (Dialog.Label1.Caption = UserText) and
      (Dialog.CancelBtn.Caption = CancelText), 'new captions');
    Dialog.Show; SetActiveWindow(Dialog.Handle); GetWindowText(Dialog.Handle, Buffer, SizeOf(Buffer));
    Check((StrPas(Buffer) = NewTitle) and Dialog.Edit1.Focused, 'native title/focus');
    Dialog.Caption := ChangeTitle; Dialog.Edit1.Text := 'invalid_'; Dialog.OKBtn.Click;
    Check((Driver.Last = SInvalidUserName) and (Dialog.ModalResult = mrNone), 'mode independent');
end;
procedure ChangeChecks(const ChangeTitle: string);
begin
    Dialog.Hide; Dialog.InitChangePassword('old');
    Check((Dialog.Caption = ChangeTitle) and (Dialog.Edit1.PasswordChar = '*') and
      (Dialog.Edit1.MaxLength = 127) and (Dialog.Edit1.Text = ''), 'change captions/reset');
    Dialog.Show;
    Dialog.Edit1.Text := 'wrong';
    Dialog.OKBtn.Click;
    Check((Driver.Last = SInvalidOldPassword) and (Driver.Errors = 2) and Driver.Valid, 'localized errors');
    Dialog.Edit1.Text := 'old'; Dialog.Edit2.Text := 'new'; Dialog.Edit3.Text := 'new'; Dialog.OKBtn.Click;
    Check((Dialog.ModalResult = mrOK) and (Dialog.Edit2.Text = 'new'), 'caller result');
end;
procedure RecreateChecks(const NewTitle: string);
begin
    Dialog.Hide; Dialog.InitNewUser; Dialog.DestroyHandle; Dialog.Show;
    Check(Dialog.Edit1.Focused and (Dialog.Edit1.PasswordChar = #0) and
      (Dialog.Caption = NewTitle), 'recreate');
    Dialog.Hide; Dialog.Edit1.Free;
    Check((Dialog.Edit1 = nil) and (Dialog.InitialControl = nil), 'field lifetime');
end;
procedure Language(const Code, NewTitle, ChangeTitle, UserText, CancelText: string; Prefix: Char);
begin
  Check(Catalog.SelectLanguage(Code), Code);
  Dialog := TPasswordDlg.Create(nil);
  Check(StackGuardIntact, 'stack create'); FillChar(StackBottom^, 64, $A5);
  try
    Driver.Errors := 0; Driver.Valid := True; Driver.Prefix := Prefix;
    NewUserChecks(NewTitle, ChangeTitle, UserText, CancelText);
    Check(StackGuardIntact, 'stack new'); FillChar(StackBottom^, 64, $A5);
    ChangeChecks(ChangeTitle);
    Check(StackGuardIntact, 'stack change'); FillChar(StackBottom^, 64, $A5);
    FailedInitialization;
    Check(StackGuardIntact, 'stack failed init'); FillChar(StackBottom^, 64, $A5);
    RecreateChecks(NewTitle);
    Check(StackGuardIntact, 'stack recreate'); FillChar(StackBottom^, 64, $A5);
  finally Dialog.Free; Dialog := nil; end;
end;
begin
  FillChar(StackBottom^, 64, $A5);
  LogLine('STEP password languages'); FillChar(Driver, SizeOf(Driver), 0);
  try
    Catalog := TFormTextCatalog.Create('C:\'); PreviousForm := SetFormTextProvider(Catalog.Translate);
    PreviousResource := SetResourceTextProvider(Catalog.TranslateResource);
    try
      Language('de', 'Neuen Benutzer anlegen', 'Kennwort '#228'ndern', 'Benutzername:', 'Abbrechen', 'D');
      Language('fr', 'Cr'#233'er un nouvel utilisateur', 'Changer de mot de passe',
        'Nom d''utilisateur :', 'Annuler', 'L');
      Language('en', 'Create new user', 'Change password', 'User name:', 'Cancel', 'T');
    finally SetResourceTextProvider(PreviousResource); SetFormTextProvider(PreviousForm); end;
    Check(LocalLoadStr(SCreateNewUser) = 'Create new user', 'bound fallback restored');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Catalog.Free;
  Check(StackGuardIntact, 'stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
