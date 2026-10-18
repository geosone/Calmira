program TestDriveChange;

{$mode delphi}
{$H-}

uses DriveChange;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn('FAIL: ', MessageText);
    Halt(1);
  end;
end;

function Observation(Monitored, Ready: Boolean; Capacity: Longint;
  const VolumeLabel: string): TMediaObservation;
begin
  Observation.Monitored := Monitored;
  Observation.Ready := Ready;
  Observation.Capacity := Capacity;
  Observation.VolumeLabel := VolumeLabel;
end;

var
  EmptySlot, Inserted, Replacement, Unmonitored: TMediaObservation;
begin
  EmptySlot := Observation(True, False, -1, '');
  Inserted := Observation(True, True, 1000, 'ARCHIVE');
  Replacement := Observation(True, True, 2000, 'BACKUP');
  Unmonitored := Observation(False, False, -1, '');

  Check(not MediaObservationChanged(EmptySlot, EmptySlot),
    'an unchanged empty slot must remain quiet');
  Check(MediaObservationChanged(EmptySlot, Inserted),
    'insertion must be detected');
  Check(MediaObservationChanged(Inserted, EmptySlot),
    'removal must be detected');
  Check(MediaObservationChanged(Inserted, Replacement),
    'replacement in the same drive letter must be detected');
  Check(not MediaObservationChanged(Unmonitored, Unmonitored),
    'unmonitored drives must remain quiet');

  Check(PollIntervalElapsed(2000, 0, 2000),
    'the initial poll must be due');
  Check(not PollIntervalElapsed(2999, 2000, 1000),
    'polling must be rate limited');
  Check(PollIntervalElapsed(3000, 2000, 1000),
    'the complete interval must be due');
  Check(PollIntervalElapsed(10, 2147483640, 1000),
    'clock wrap must trigger a poll');

  WriteLn('drivechange tests: OK');
end.
