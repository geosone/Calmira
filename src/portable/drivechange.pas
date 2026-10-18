{ Portable removable-media change detection.

  Keep this unit free of operating-system and GUI dependencies. Platform
  adapters create observations; this unit decides whether a refresh is due. }
unit DriveChange;

{$IFDEF FPC}
  {$mode delphi}
  {$H-}
{$ENDIF}

interface

type
  TMediaObservation = record
    Monitored: Boolean;
    Ready: Boolean;
    Capacity: Longint;
    VolumeLabel: string[11];
  end;

function MediaObservationChanged(const Previous,
  Current: TMediaObservation): Boolean;
function PollIntervalElapsed(NowTick, LastTick,
  Interval: Longint): Boolean;

implementation

function MediaObservationChanged(const Previous,
  Current: TMediaObservation): Boolean;
begin
  if Previous.Monitored <> Current.Monitored then
    MediaObservationChanged := True
  else if not Current.Monitored then
    MediaObservationChanged := False
  else if Previous.Ready <> Current.Ready then
    MediaObservationChanged := True
  else if not Current.Ready then
    MediaObservationChanged := False
  else
    MediaObservationChanged :=
      (Previous.Capacity <> Current.Capacity) or
      (Previous.VolumeLabel <> Current.VolumeLabel);
end;

function PollIntervalElapsed(NowTick, LastTick,
  Interval: Longint): Boolean;
begin
  { The clock used by Win16 wraps. Treat a wrap as immediately due. }
  PollIntervalElapsed := (LastTick = 0) or (NowTick < LastTick) or
    (NowTick - LastTick >= Interval);
end;

end.
