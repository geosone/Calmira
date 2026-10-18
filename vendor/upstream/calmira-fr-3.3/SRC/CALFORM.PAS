{**************************************************************************}
{                                                                          }
{    Calmira II shell pour Microsoft® Windows(TM) 3.1                      }
{    Version française 3.3                                                 }
{    Copyright (C) 2000-2002 Jean Blanchard                                }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    Ce programme est libre ; vous pouvez le redistribuer et/ou le         }
{    modifier selon les termes de la Licence Publique Générale GNU telle   }
{   que publiée par la Free Software Foundation ; version 2 de la licence  }
{    ou (au choix) n'importe quelle version plus récente.                  }
{                                                                          }
{    Ce programme est distibué dans l'espoir qu'il sera utile, mais SANS   }
{    AUCUNE GARANTIE ; sans même la garantie implicite de                  }
{    COMMERCIALISATION ou d'APTITUDE A UN USAGE PARTICULIER. Voir la       }
{    licence publique générale pour plus de détails.                                        }
{                                                                          }
{    Vous devriez avoir reçue une copie de la licence publique générale    }
{    avec ce programme; si ce n'est pas le cas, écrivez à la Free          }
{    Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.    }
{                                                                          }
{--------------------------------------------------------------------------}

unit CalForm;

{ TCalForm is the common ancestor of most of Calmira's modeless windows,
  and you should use it for other modeless windows that you add.

  The main feature is the use of WMSettingsChanged to trigger the
  SettingsChanged method.  Descendants override this to adjust their
  properties depending on which settings have been modified.

  3.1 -- All StretchShift and related methods are moved to ExtForm. }

interface

uses Forms, ExtForm, Messages, Classes, Controls, WinProcs, WinTypes,
  CalMsgs, Settings;

type
  TCalForm = class(TExtForm)
  private
    { Private declarations }
    procedure WMSettingsChanged(var Msg: TMessage); message WM_SETTINGSCHANGED;
  protected
    { Protected declarations }
    procedure CreateParams(var Params: TCreateParams); override;
  public
    { Public declarations }
    procedure SettingsChanged(Changes: TSettingChanges); virtual;
  end;

implementation

procedure TCalForm.WMSettingsChanged(var Msg: TMessage);
begin
  SettingsChanged(TSettingChanges(Msg.wParam));
end;

procedure TCalForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if DesktopParent then Params.WndParent := GetDesktopWindow;
end;

procedure TCalForm.SettingsChanged(Changes: TSettingChanges);
begin
end;

end.

