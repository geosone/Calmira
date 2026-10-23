{ Based on Jean Blanchard's public-domain French Calmira 3.3 NHEADER.PAS.
  Adapted 2026: preserve inherited mouse handling and ignore resize dividers. }
unit NHeader;
interface
uses Classes, Controls, ExtCtrls;
type
  TSClickEvent = procedure(Sender: TObject; Section: Integer) of object;
  TNewHeader = class(THeader)
  private
    FOnSectionClick: TSClickEvent;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
  published
    property OnSectionClick: TSClickEvent
      read FOnSectionClick write FOnSectionClick;
  end;
procedure Register;
implementation
uses header_sections;
procedure TNewHeader.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Widths: array[0..255] of Integer;
  I, Hit, Count: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Assigned(FOnSectionClick) then Exit;
  Count := Sections.Count;
  if Count > 256 then Count := 256;
  FillChar(Widths, SizeOf(Widths), 0);
  for I := 0 to Count - 1 do Widths[I] := SectionWidth[I];
  if Count = 0 then Exit;
  Hit := HeaderSectionAt(X, Widths, 3);
  if Hit >= 0 then FOnSectionClick(Self, Hit);
end;
procedure Register;
begin
  RegisterComponents('Calmira', [TNewHeader]);
end;
end.
