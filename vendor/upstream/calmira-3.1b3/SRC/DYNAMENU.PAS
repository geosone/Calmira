{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.1                                                   }
{    Copyright (C) 1998-2000 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    This program is free software; you can redistribute it and/or modify  }
{    it under the terms of the GNU General Public License as published by  }
{    the Free Software Foundation; either version 2 of the License, or     }
{    (at your option) any later version.                                   }
{                                                                          }
{    This program is distributed in the hope that it will be useful,       }
{    but WITHOUT ANY WARRANTY; without even the implied warranty of        }
{    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         }
{    GNU General Public License for more details.                          }
{                                                                          }
{    You should have received a copy of the GNU General Public License     }
{    along with this program; if not, write to the Free Software           }
{    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.             }
{                                                                          }
{**************************************************************************}

unit DynaMenu;

interface

uses Classes, Menus;

type
  TDynamicMenu = class(TPopupMenu)
  private
    function GetElement(ID: Integer): TMenuItem;
  public
    procedure AddItem(const Caption: string; Shortcut: TShortcut;
      Checked, Enabled: Boolean; ID: Integer);
    procedure AddLine;
    procedure Attach(const Handlers: array of TNotifyEvent);
    procedure Detach;
    procedure Click(ID: Integer);
    property Element[ID: Integer]: TMenuItem read GetElement;
  end;

implementation

procedure TDynamicMenu.AddItem(const Caption: string; Shortcut: TShortcut;
  Checked, Enabled: Boolean; ID: Integer);
var
  m: TMenuItem;
begin
  m := NewItem(Caption, Shortcut, Checked, Enabled, nil, 0, '');
  m.Tag := ID;
  Items.Add(m);
end;

procedure TDynamicMenu.AddLine;
begin
  AddItem('-', 0, False, True, -1);
end;

procedure TDynamicMenu.Attach(const Handlers: array of TNotifyEvent);
var
  i, j: Integer;
begin
  i := 0;
  j := 0;
  while (i < Items.Count) and (j <= High(Handlers)) do
  begin
    if Items.Items[i].Tag <> -1 then
    begin
      Items.Items[i].OnClick := Handlers[j];
      Inc(j);
    end;
    Inc(i);
  end;
end;

procedure TDynamicMenu.Detach;
var
  i: Integer;
begin
  for i := 0 to Items.Count - 1 do Items.Items[i].OnClick := nil;
end;

function TDynamicMenu.GetElement(ID: Integer): TMenuItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Items.Count-1 do if Items[i].Tag = ID then
  begin
    Result := Items[i];
    Exit;
  end;
end;

procedure TDynamicMenu.Click(ID: Integer);
var
  m: TMenuItem;
begin
  m := Element[ID];
  if m <> nil then m.Click;
end;

end.

