{*********************************************************}
{                                                         }
{    Calmira Visual Component Library 2.2                 }
{    by Li-Hsin Huang,                                    }
{    released into the public domain July 1998            }
{                                                         }
{*********************************************************}

unit CalVCL;

interface

procedure Register;

implementation

uses Classes, MultiGrd, DropServ, DropClnt, BarGauge, StylSped,
 ApHolder, ChkList, ScrTree, SysMenu, IconDlg, Internet,
 LabelSel, Notepad, TabPanel, PicBtn;

procedure Register;
begin
  RegisterComponents('Calmira',
    [TMultiGrid, TDropServer, TDropClient, TBarGauge,
      TStyleSpeed, TAppHolder, TCheckList, TScrollTree,
      TSystemMenu, TBrowserLink, TLabelSelect, TNotepad, TWin95Gauge,
      TTabPanel, TPicBtn]);

  RegisterComponents('Dialogs', [TIconDialog]);
end;


end.
