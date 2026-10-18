{*********************************************************}
{                                                         }
{    Calmira Visual Component Library 3.0                 }
{    by Li-Hsin Huang,                                    }
{    released into the public domain july 2000            }
{                                                         }
{*********************************************************}

unit CalVCL;

interface

procedure Register;

implementation

uses Classes, MultiGrd, DropServ, DropClnt, BarGauge, StylSped,
 ApHolder, ChkList, ScrTree, SysMenu, IconDlg, Internet, LabelSel,
 Notepad, TabPanel, PicBtn, Slider, Win95Pie, NetDlgs;

procedure Register;
begin
  RegisterComponents('Calmira', [TSystemMenu, TLabelSelect,
    TNotepad, TAppHolder, TMultiGrid, TScrollTree, TCheckList,
    TBrowserLink, TDropServer, TDropClient, TPicBtn, TStyleSpeed,
    TBarGauge, TWin95Gauge, TTabPanel, TSlider, TWin95PieChart]);
  RegisterComponents('Dialogs', [TIconDialog,
    TNetConnectDialog, TNetDisconnectDialog,
    TNetShareAsDialog, TNetStopShareDialog]);
end;

end.

