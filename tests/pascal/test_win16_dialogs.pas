program DialogsTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Messages, Classes, SysUtils, Controls, Forms, Dialogs, form_text;
type
  TCatalog = class
    function Translate(const RootClass, ComponentName, PropertyName,
      DefaultText: string): string;
  end;
{$I win16_dialog_driver.inc}
function TCatalog.Translate(const RootClass, ComponentName, PropertyName,
  DefaultText: string): string;
begin
  Result := DefaultText;
  if (RootClass = 'TMessageForm') and (ComponentName = 'Yes') then Result := '&Ja'
  else if (RootClass = 'TMessageForm') and (ComponentName = 'Confirm') then Result := 'Frage'
  else if (RootClass = 'TStandardButtons') and (ComponentName = 'Cancel') then Result := 'Abbrechen';
end;
procedure RunSteps;
var Answer: Word; Text: string; ShortHeight: Integer; Catalog: TCatalog;
  Previous: TFormTextProvider;
begin
  Script(akKey, VK_RETURN, '');
  Answer := MessageDlg('Hello', mtInformation, [mbOK], 0);
  Check(Driver.Acted and (Answer = mrOk) and (Driver.Caption = 'Information') and
    (Driver.Children = 'OK') and (Driver.FocusText = 'OK'), 'info');
  ShortHeight := Driver.Height;
  Script(akKey, VK_ESCAPE, '');
  Answer := MessageDlg('Replace?', mtConfirmation, mbYesNoCancel + [mbAll], 0);
  Check((Answer = mrCancel) and (Driver.Caption = 'Confirm') and
    (Driver.Children = '&Yes|&No|Cancel|&All') and (Driver.FocusText = '&Yes'), 'confirm');
  Script(akClick, 0, '&All');
  Answer := MessageDlg('Replace?', mtConfirmation, mbYesNoCancel + [mbAll], 0);
  Check(Answer = mrAll, 'click All');
  Script(akKey, VK_ESCAPE, '');
  Answer := MessageDlg('Delete?', mtWarning, [mbYes, mbNo], 0);
  Check((Answer = mrNo) and (Driver.Caption = 'Warning'), 'Escape No');
  Script(akKey, VK_RETURN, '');
  Answer := MessageDlg('Disk', mtError, mbAbortRetryIgnore, 0);
  Check((Answer = mrAbort) and (Driver.Caption = 'Error') and (Driver.FocusText = '&Abort'), 'first');
  Text := ''; for I := 1 to 30 do Text := Text + 'word ';
  Script(akKey, VK_RETURN, '');
  Answer := MessageDlg(Text + #13#10'x', mtWarning, [mbOK], 0);
  Check((Answer = mrOk) and (Driver.Height >= ShortHeight + 20) and
    (Driver.Width <= GetSystemMetrics(SM_CXSCREEN) div 2 + 80), 'wrap');
  Script(akKey, VK_RETURN, '');
  ShowMessage('Plain');
  Check(Driver.Acted and (Driver.Caption = Application.Title) and (Driver.Children = 'OK'), 'ShowMessage');
  Catalog := TCatalog.Create; Previous := SetFormTextProvider(Catalog.Translate);
  try
    Script(akKey, VK_ESCAPE, '');
    Answer := MessageDlg('?', mtConfirmation, mbYesNoCancel, 0);
    Check((Answer = mrCancel) and (Driver.Caption = 'Frage') and
      (Driver.Children = '&Ja|&No|Abbrechen'), 'language');
  finally SetFormTextProvider(Previous); Catalog.Free; end;
  StartResources;
  for I := 1 to 5 do begin Script(akKey, VK_RETURN, ''); MessageDlg('Cycle', mtInformation, [mbOK], 0); end;
  Check(ResourcesKept, 'resources');
end;
begin
  RunDriver('message dialogs');
end.
