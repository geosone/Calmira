{*********************************************************}
{                                                         }
{    Librairie Système Calmira 3.3                        }
{    par Li-Hsin Huang & Erwin Dokter                     }
{    Traduction par Jean Blanchard                        }
{    publié dans le domaine public en Juillet 2002        }
{                                                         }
{*********************************************************}

unit CalVCL;

interface

procedure Register;

implementation

uses Classes, ApHolder, SysMenu, LabelSel, DropServ, DropClnt,
  StylSped, PicBtn, ChkList, PathCmbo, ScrTree, MultiGrd, Internet,
  BarGauge, Win95Pie, TabPanel, Slider, NHeader, SortHdr, IconDlg, NetDlgs;

procedure Register;
begin
  RegisterComponents('Calmira', [TAppHolder, TSystemMenu,
    TLabelSelect, TPathComboBox, TScrollTree, TMultiGrid, TCheckList,
    TBrowserLink, TDropServer, TDropClient, TPicBtn, TStyleSpeed,
    TBarGauge, TWin95Gauge, TWin95PieChart, TTabPanel, TSlider,
    TNewHeader, TSortHeader]);
  RegisterComponents('Dialogues', [TIconDialog,
    TNetConnectDialog, TNetDisconnectDialog,
    TNetShareAsDialog, TNetStopShareDialog]);
end;

end.
