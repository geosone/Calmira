{*********************************************************}
{                                                         }
{    Calmira Visual Component Library 2.0                 }
{    by Li-Hsin Huang,                                    }
{    released into the public domain October 1997         }
{                                                         }
{*********************************************************}

unit CalVCL;

interface

procedure Register;

implementation

uses Classes, MultiGrd, DropServ, DropClnt, BarGauge, StylSped,
 ApHolder, ChkList, ScrTree, SysMenu, IconDlg, Internet,
 LabelSel, Notepad;

procedure Register;
begin
  RegisterComponents('Calmira',
    [TMultiGrid, TDropServer, TDropClient, TBarGauge,
      TStyleSpeed, TAppHolder, TCheckList, TScrollTree,
      TSystemMenu, TBrowserLink, TLabelSelect, TNotepad]);

  RegisterComponents('Dialogs', [TIconDialog]);
end;


end.
