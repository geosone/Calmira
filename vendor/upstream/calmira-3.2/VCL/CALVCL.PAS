{*********************************************************}
{                                                         }
{    Calmira System Library 3.1                           }
{    by Li-Hsin Huang & Erwin Dokter                      }
{    released into the public domain january 2002         }
{                                                         }
{*********************************************************}

unit CalVCL;

interface

procedure Register;

implementation

uses Classes, ApHolder, SysMenu, LabelSel, DropServ, DropClnt,
  StylSped, PicBtn, ChkList, PathCmbo, ScrTree, MultiGrd, Internet,
  BarGauge, TabPanel, Slider, Win95Pie, IconDlg, NetDlgs;

procedure Register;
begin
  RegisterComponents('Calmira', [TAppHolder, TSystemMenu,
    TLabelSelect, TPathComboBox, TScrollTree, TMultiGrid, TCheckList,
    TBrowserLink, TDropServer, TDropClient, TPicBtn, TStyleSpeed,
    TBarGauge, TWin95Gauge, TTabPanel, TSlider, TWin95PieChart]);
  RegisterComponents('Dialogs', [TIconDialog,
    TNetConnectDialog, TNetDisconnectDialog,
    TNetShareAsDialog, TNetStopShareDialog]);
end;

end.

