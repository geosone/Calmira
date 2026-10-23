{ Observe the declared stack reservation, not merely the NE static budget. }
function StackGuardIntact: Boolean;
type TGuard = array[0..63] of Byte; PGuard = ^TGuard;
var Index: Integer;
begin
  Result := False;
  for Index := 0 to 63 do
    if PGuard(StackBottom)^[Index] <> $A5 then Exit;
  Result := True;
end;
