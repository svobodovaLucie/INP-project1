# Návrh počítačových systémů (INP) - projekt 1

Cílem tohoto projektu je implementovat pomocí VHDL procesor, který bude schopen vykonávat program
napsaný v jazyce Brainlove. Jazyk Brainlove je rozšířením jazyka BrainF*ck, který používá pouze
osm jednoduchých příkazů (instrukcí), o pět nových instrukcí. Ačkoliv jazyk BrainF*ck používá pouze osm
jednoduchých příkazů (instrukcí), jedná se o výpočetně úplnou sadu, pomocí které je možné implementovat
libovolný algoritmus. Na ověření korektní funkce poslouží několik testovacích programů (výpis textu, výpis
prvočísel, rozklad čísla na prvočísla, apod.).

#### HODNOCENÍ: 21/23

Overeni cinnosti kodu CPU:  
   \# |  testovany program (kod)    |   vysledek  
   -|-|-
   1.|  ++++++++++                   | ok  
   2.|  ----------                   | ok  
   3.|  +>++>+++                     | ok  
   4.|  <+<++<+++                    | ok  
   5.|  .+.+.+.                      | ok  
   6.|  ,+,+,+,                      | chyba  
   7.|  [........]noLCD[.........]   | ok  
   8.|  +++[.-]                      | ok  
   9.|  +++++[>++[>+.<-]<-]          | ok  
  10.|  +[+~.------------]+          | ok  
  
  Podpora jednoduchych cyklu: ano  
  Podpora vnorenych cyklu: ano  
  
Poznamky k implementaci:  
Nekompletni sensitivity list; chybejici signaly: CODE_DATA, cnt_num  
Mozne problematicke rizeni nasledujicich signalu: OUT_DATA  
