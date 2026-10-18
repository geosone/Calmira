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

unit Embed;

interface

const
  SSSelectedItems   = '%d objets sélectionnés   %s';
  SSSelectedOneItem = '%d objet sélectionné   %s';
  SSNumObjects      = '%d objet%s   %s';
  SSNumTasks        = '%d tâche%s'; { 3.11 }
  SSNoDescription   = '';
  SSNoNetConnection = '(Aucune)';
  SSItemsFound      = '%d objets trouvés';
  SSFoundSelected   = '%d sélectionnés';
  SSDrive           = 'Lecteur (%s:)¬%s';
  SSParallelPort    = 'Port parallèle LPT%s¬%s';

const
  SelectionLabels: array[Boolean] of string[23] =
    (SSSelectedItems, SSSelectedOneItem); { 2.2 }

  SSUnknownDrive = 'Inconnu (%s:)';
  SSNoDrive      = 'Pas de lecteur (%s:)';
  SSFloppyDrive  = 'Disquette (%s:)';
  SSFixedDrive   = 'Disque dur (%s:)';
  SSNetworkDrive = 'Réseau (%s:)';
  SSCDROMDrive   = 'CD-ROM (%s:)';
  SSRamDrive     = 'RAMdisk (%s:)';

implementation

end.
