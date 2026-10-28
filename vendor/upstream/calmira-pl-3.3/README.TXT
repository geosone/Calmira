{**************************************************************************}
{                                                                          }
{    Calmira II - pow³oka Microsoft® Windows(TM) 3.1                       }
{    Wersja Online! 3.3 polska                                            }
{    Copyright (C) 1998-2000 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    Ten program jest darmowy; mo¿na go rozpowszechniaæ i modyfikowaæ      }
{    pod warunkiem zachowania GNU General Public License opublikowanej     }
{    przez Free Software Foundation; dotyczy to wersji 2 Licencji, jak     }
{    te¿ ka¿dej nastêpnej wersji.                                          }
{                                                                          }
{    Ten program jest rozpowszechniany w nadziei, ¿e bêdzie u¿yteczny,     }
{    ale BEZ ¯ADNEJ GWARANCJI; nawet bez gwarancji PRZYDATNOŒCI            }
{    DO JAKIEGOKOLWIEK ZASTOSOWANIA. Zajrzyj do GNU General Public         }
{    License po wiêcej szczegó³ów (licence.txt).                           }
{                                                                          }
{    Kopia GNU General Public License powinna byæ do³¹czona do tego        }
{    programu; jeœli nie, napisz do Free Software Foundation, Inc.,        }
{    675 Mass Ave, Cambridge, MA 02139, USA.                               }
{                                                                          }
{**************************************************************************}


Calmira jest interfejsem u¿ytkownika w stylu Windows 95, daj¹cym wszelkie 
mo¿liwoœci zarz¹dzania aplikacjami i plikami w systemie Windows 3.1x. Program 
mo¿e byæ uruchamiany ju¿ na komputerach z procesorami 386 i 486.

Calmira to:

o  mo¿liwoœæ definiowania ró¿nych ustawieñ dla poszczególnych u¿ytkowników
o  zarz¹dzanie plikami wyœwietlanymi w oddzielnych oknach
o  u¿ywanie opisów 4DOS jako substytutu d³ugich nazw plików
o  tworzenie skrótów i aliasów do dowolnych obiektów (w tym do adresów
   internetowych)
o  poruszanie siê po zasobach systemu za pomoc¹ drzewa Eksploratora
o  Pasek zadañ z rozwijanym do dowolnego poziomu menu
o  Kosz przechowuj¹cy usuwane pliki i foldery
o  setki ³atwo dostêpnych opcji i ustawieñ
o  80-stronicowa dokumentacja zawieraj¹ca wszelkie potrzebne informacje 
   i pomoc


Nowoœci w 3.3PL:
------------------

+ Taskbar QuickLaunch (przybornik w pasku zadañ).
+ W³aœciwoœci CD-ROM'u pokazuj¹ w³aœciwy rozmiar dysku .
+ Mo¿liwa jest zmiana wielkoœci niektórych okien dialogowych.
+ W Eksploratorze mo¿liwe jest wyœwietlanie i sortowanie po typie pliku.

Calmira II 3.02 PL
------------------

Ta wersja jest swoist¹ edycj¹ zapowiadaj¹c¹ dla wersji 3.1, 
która ju¿ znajduje siê w fazie pierwszych testów, i zosta³a opublikowana
ze wzglêdu na kilka nowych, opracowanych ju¿, funkcji (poza tym ju¿ 
dawno siê nam wszystkim nale¿a³a ;-)


Nowoœci
------------

* +/- w drzewie Eksploratora rozwija/zwija drzewo 
  (bez otwierania folderu)
* mo¿liwoœæ logowania siê jako nowy u¿ytkownik
  bez restartu Calmiry/Windows (opcja w oknie
  Zamknij system - aktywuje siê, jeœli Calmira
  jest w trybie wielu u¿ytkowników)
* mo¿liwoœæ przeszukiwania zawartoœci plików 
  (zak³adka zaawansowane w oknie ZnajdŸ)
* EXPLORER.EXE akceptuje folder jako parametr
  (np explorer.exe c:\dos)
* poprawione zosta³y drobne b³êdy


===   Jeœli tylko wypróbujesz Calmirê i zobaczysz odnowione Windows 3.1   ===
===            - nigdy nie wrócisz do starego sposobu pracy...            ===


Wymagania systemu
-----------------

o  procesor i386 lub lepszy
o  Microsoft Windows 3.1 lub Windows for Workgroups 3.11
o  Przynajmniej 4 megabajty (MB) pamiêci, 8MB zalecane
o  Monitor VGA lub lepszy
o  Mysz


Instalacja
----------

Pe³na instrukcja znajduje siê w pliku pomocy.
Do szybkiego rozpoczêcia pracy z Calmir¹ wystarczy rozpakowanie ca³ego archiwum 
ZIP do katalogu na twardym dysku i uruchomienie pliku CALMIRA.EXE.


Kontakt
-------

Autor programu: Li-Hsin Huang (zrezygnowa³ z dalszej pracy nad programem)

Koordynator
prac          : Erwin Dokter
                erwin@calmira.org

Web           : http://www.calmira.org/

T³umacze      : Micha³ Rudolf     mrudolf@mercury.ci.uw.edu.pl
                Marcin Szafran    jm_sz@poczta.onet.pl
       ver3.3 : Ryszard Tykwiñski krokodylowy@wp.pl 
 
Web           : http://www.calmira.republika.pl


============================================================================
                            Z ostatniej chwili
============================================================================

Kolory Windows 95 - podczas pierwszego uruchomienia Calmira instaluje nowy 
schemat kolorów - "Windows 95 Standard" - w Panelu sterowania. Mo¿na go póŸniej 
ustawiæ zwyk³¹ metod¹. Nie dotyczy to niestety komputerów, na których Calmira
jest nadpisywana na poprzedni¹ wersjê.

Netscape Navigator i Netscape Communicator - w pliku calmira.ini w sekcji 
[Internet] powinny znaleŸæ siê nastêpuj¹ce wpisy:
   ServiceApplication=d:\netscape\netscape
   URLPrefixes=http:// ftp:// gopher:// news: file: mailto:
   CommandLine=d:\netscape\netscape.exe %url%
(jeœli aplikacja jest zainstalowana w katalogu d:\netscape).
Tak skonfigurowana Calmira poprawnie wspó³pracuje z t¹ aplikacj¹. Je¿eli jesteœ 
u¿ytkownikiem przegl¹darki Opera, to w linii ServiceApplication wpisz scie¿kê
do niej; pamiêtaj o wpisywaniu œcie¿ki bez rozszerzenia .exe! Dla Internet
Explorera i Opery wpis CommandLine= jest zbêdny. 

MS Internet Explorer - wersje 4.0x i 5.0 nale¿y instalowaæ w Mened¿erze
Programów. Calmira nie bêd¹c rzeczywistym serwerem DDE nie potrafi porozumieæ
siê poprawnie z programem instalacyjnym IE. Co wiêcej: instalator wersji 5.0
w Calmirze nie pozwala na rezygnacjê z ju¿ zainstalowanych elementów pakietu
- mo¿na tylko dodawaæ nowe, a dodatkowo po zakoñczeniu instalacji zg³aszany
jest b³¹d (nie stwierdzono przy tym wp³ywu tego b³êdu na dalsze dzia³anie
programu). Jeœli instalacjê przeprowadza siê w Mened¿erze Programów wymienione
problemy nie wystêpuj¹.

Plik calmicon.dll - pakiet Calmiry zawiera plik calmicon.dll z ikonami, które
mo¿na wykorzystaæ do zmiany wygl¹du Calmiry na styl Windows95 (menu Start,
ikony Komputera i Kosza, itd). Do³¹czone do archiwum pliki calmira.ini
i start.ini zawieraj¹ odwo³ania do tej w³aœnie biblioteki. Calmicon.dll jest
odpowiednikiem w95icons.dll publikowanego z oryginaln¹ Calmir¹ II 3.0 i 3.01
Online! i pakietem Win95 Desktop Theme (w95theme.zip), jest jednak inaczej
- naszym zdaniem bardziej logicznie - uporz¹dkowany, dziêki temu ³atwiej
odnaleŸæ rz¹dan¹ ikonê. Dodatkowo niektóre wersje biblioteki w95icons.dll
zawiera³y ikony o rozmiarze 16x16 pikseli i mog³y powodowaæ b³êdy lub
niestabilnoœæ sterowników graficznych - calmicon.dll (podobnie zreszt¹ jak
w95icons.dll w wersji 3.01) ma ju¿ wy³¹cznie ikony o rozmiarach 32x32 piksele.
Plik w95icons.dll mo¿na œci¹gn¹æ z oœrodka Calmiry: http://www.calmira.org/.
