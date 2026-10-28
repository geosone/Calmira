unit delphi_asm_probe;
{$mode delphi}
interface
{ Declared without "assembler", implemented in assembler below, as Delphi 1
  units such as MiscUtil do: callers pass the parameters on the stack. }
function ProbeSub(A, B: Integer): Integer;
implementation
function ProbeSub(A, B: Integer): Integer; assembler;
asm
  MOV AX,A
  SUB AX,B
end;
end.
