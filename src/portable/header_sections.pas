{ Portable hit testing for Calmira's clickable column header. }
unit header_sections;
{$IFDEF FPC}{$mode delphi}{$H-}{$ENDIF}
interface
function HeaderSectionAt(X: Integer; const Widths: array of Integer;
  DividerMargin: Integer): Integer;
implementation
function HeaderSectionAt(X: Integer; const Widths: array of Integer;
  DividerMargin: Integer): Integer;
var
  I: Integer;
  LeftEdge, RightEdge: Longint;
begin
  HeaderSectionAt := -1;
  if (X < 0) or (DividerMargin < 0) then Exit;
  LeftEdge := 0;
  for I := 0 to High(Widths) do
  begin
    if Widths[I] < 0 then Exit;
    RightEdge := LeftEdge + Widths[I];
    if (X > LeftEdge + DividerMargin) and
      (X < RightEdge - DividerMargin) then
    begin
      HeaderSectionAt := I;
      Exit;
    end;
    LeftEdge := RightEdge;
  end;
end;
end.
