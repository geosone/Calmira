program InputQueryTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,1024}
uses WinTypes, WinProcs, Win31, Messages, Classes, SysUtils, Controls, Forms, Dialogs;
{$I win16_dialog_driver.inc}
procedure RunSteps;
var Value: string; Okay: Boolean;
begin
  Value := 'old'; Script(akChars, 0, 'new');
  Okay := InputQuery('Rename', 'New name:', Value);
  Check(Okay and (Value = 'new') and (Driver.Caption = 'Rename') and
    (Driver.Children = 'old|OK|Cancel') and (Driver.FocusText = 'old') and
    (Driver.SelStart = 0) and (Driver.SelEnd = 3), 'accept');
  Value := 'keep'; Script(akKey, VK_ESCAPE, '');
  Okay := InputQuery('Rename', 'New name:', Value);
  Check(not Okay and (Value = 'keep'), 'cancel');
  Script(akKey, VK_ESCAPE, '');
  Check(InputBox('Box', 'Prompt', 'default') = 'default', 'InputBox');
  StartResources;
  for I := 1 to 5 do begin Value := 'x'; Script(akKey, VK_ESCAPE, ''); InputQuery('Cycle', 'Value', Value); end;
  Check(ResourcesKept, 'resources');
end;
begin
  RunDriver('input query');
end.
