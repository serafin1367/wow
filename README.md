# WOW — robotyczna kolonia (Godot 4.x)

WOW to prototyp ekonomicznej gry strategicznej 3D z kamera RTS.
Celem jest rozwoj **samowystarczalnej kolonii robotow na obcej planecie**.
Inspiracja gatunkiem: automatyzacja produkcji i logistyka; oprawa wizualna jest nasza, tworzona w Godot z proceduralnych meshow low-poly.

## WOW 0.12 — drogi techniczne, projekty kolonii i budowa seryjna

### Przejezdne drogi techniczne — D

Po nacisnieciu **D** gracz przechodzi w tryb rysowania drogi:
1. **LPM** wybiera jej poczatek. Przesun mysz, aby obejrzec trase A*.
2. Kolejny **LPM** dodaje punkt posredni/zakret; mozna wskazac do 12 punktow.
3. **Enter** buduje wszystkie nowe fragmenty. **Backspace** cofa ostatni
   punkt, **Esc/PPM** anuluje bez pobrania materialow.

Koszt: **1 kamien za kazde rozpoczęte 4 NOWE pola drogi**. Stare
segmenty mozna wykorzystac ponownie za darmo. Droga nie posiada kolizji
i prowadzi roboty po dotychczasowej siatce A*, bez zmiany ich tras.
Na wybrukowanym terenie roboty poruszaja sie **o 25% szybciej**.
Pojedynczy projekt drogi moze miec do 160 pol. Drogi nie wchodza na
zablokowane pola i rezerwuja swoj obszar przed nowymi budynkami.

### Plan grupy budynkow — F / Shift+LPM

- **F** wlacza i wylacza tryb **PLANOWANIA**. Kiedy F jest aktywne,
  LPM dodaje polprzezroczysty hologram wybranego budynku do projektu
  (nie buduje go od razu).
- Niezaleznie od F, mozna dodac pojedynczy budynek do projektu przez
  **Shift+LPM** w trybie budowania.
- Zmieniaj typy budynkow (M kopalnia, H huta, B centrum, L rekultywacja,
  V panel, K bateria), orientacje R i siatke G; plan zostaje na mapie.
- **Enter** zatwierdza caly projekt i pobiera zsumowane koszty *raz*,
  dopiero gdy wszystkie elementy nadal sa dozwolone i wystarcza surowcow.
- **Backspace** usuwa ostatni zaplanowany element; **Delete** kasuje
  caly projekt bez kosztow. Esc anuluje aktualny tryb budowania,
  ale nie kasuje zapisanych hologramow (uzyj Delete).
- Maksymalnie 12 konstrukcji w jednym projekcie. Weryfikacja blokuje
  nakladanie projektow na budynki, zloza i drogi, pilnuje limitow
  poszczegolnych typow.

**Prosty lancuch produkcyjny:** F -> M -> LPM na zlozu zelaza ->
H -> LPM na wolnym terenie -> Enter. Kopalnia i huta powstaja
razem, a transportowiec otrzymuje zwykle zadanie dostaw. Pozniej
mozna ukladac drogi D i automatyczne tasmy J/N (te ostatnie
wymagaja metalu wyprodukowanego przez hute). Planowanie tasmociagow
**nie jest jeszcze czescia transakcji zbiorczej**.

### Budowa seryjna — X

**X** przelacza tryb SERIA. Dla powtarzalnych konstrukcji
(rekultywacja **L**, panel PV **V**, akumulator **K**) po udanym
LPM pozostajesz w trybie budowania i mozesz postawic nastepny
egzemplarz bez ponownego wybierania przycisku.
Seria zatrzymuje sie po wyczerpaniu surowcow lub limitu budynkow;
Esc/PPM konczy tryb. Pojedyncze centrum, kopalnia i huta pozostaja
jednorazowymi konstrukcjami.

Kod: `scripts/technical_roads.gd`,
`scripts/construction_blueprints.gd`, `scripts/main.gd`
i `scripts/worker.gd`. Weryfikacja:
`tests/infrastructure_planning_smoke.gd` na GitHub Actions.

Po `git pull origin main`: najpierw sprawdz D i budowe drogi,
a nastepnie F -> M -> klik na zelazo -> H -> klik na wolne pole
-> Enter. Sprawdz tez, czy Delete usuwa hologramy i zachowuje zasoby.

## WOW 0.11 — hologram modelu 3D, obroty i modularna siatka budowy

Po wybraniu konstrukcji (B centrum, L rekultywacja, M kopalnia,
H huta, V panel PV, K bateria) widac teraz **prawdziwy, polprzezroczysty
model 3D budynku** pod kursorem, na lokalnej zielono-czerwonej siatce.

- **Zielony hologram i obrys**: mozna postawic budynek.
- **Czerwony hologram i obrys**: caly budynek nie miesci sie,
  koliduje z istniejacymi obiektami lub granica mapy.
- **R**: obrot o 90 stopni zgodnie z ruchem wskazowek zegara.
- **Shift+R**: obrot o 90 stopni w druga strone.
- **G**: zmiana siatki przyciagania **1 m -> 2 m -> 4 m -> 1 m**.
- **LPM**: zatwierdzenie budowy po sprawdzeniu zajetosci terenu.
- **Esc/PPM**: anulowanie bez pobrania zasobow.

Obrot dotyczy rzeczywistego modelu i jego fizycznej kolizji,
a budynek otrzymuje dokladnie taka sama orientacje jak hologram.
Kolo rezerwacji terenu wokol budynku pozostaje konserwatywne,
niezalezne od jego obrotu, by zachowac bezpieczenstwo nawigacji robotow.

Podglad nie posiada warstwy kolizji, nie uruchamia
produkcji, timerow rekultywacji ani animacji.
W miejscu budowy tworzony jest prawdziwy budynek dopiero po
potwierdzeniu, wiec system gospodarki pozostaje bez zmian.

**Wyjatek:** kopalnia ma stala lokalizacje na zlozu zelaza,
nie mozna przesunac jej poza to zloze przez zmiane siatki G;
orientacje (R) nadal mozna wybrac.

Kod: `scripts/building_ghost.gd`,
`scripts/build_placement_preview.gd`,
`scripts/main.gd`.
Test integracyjny: `tests/building_ghost_smoke.gd` sprawdza
6 rodzajow hologramow, brak kolizji i wydatkow, obroty i przyciaganie.

### Proponowany test w Godocie

1. `git pull origin main`, a po zakonczeniu importu uruchom F5.
2. Nacisnij V. Przesuwaj kursor z wolnego terenu nad magazyn:
   model i obrys maja zmienic kolor z zielonego na czerwony.
3. Nacisnij R, potem Shift+R — obserwuj obrot panelu.
4. Nacisnij G dwa razy — sprawdz, czy konstrukcja przesuwa
   sie po siatce 2 m, a potem 4 m.
5. Kliknij LPM w wolnym miejscu i obejrzyj gotowy, obrocony panel.
6. Powtorz z H (huta), K (bateria) i B (centrum).

## WOW 0.10 — bezpieczne stawianie budynkow: siatka przy kursorze

W trybie budowania pojawia sie **lokalna, polprzezroczysta siatka 17x17 pol**
bezposrednio wokol kursora, nad powierzchnia planety.

- **Zielone pola:** teren wolny od kolizji i przeszkod.
- **Czerwone pola:** juz zajety teren albo obszar poza mapa.
- **Zielony okrag / WOLNE MIEJSCE:** caly obrys wybranego budynku
  zmiesci sie na wskazanym stanowisku.
- **Czerwony okrag / ZAJETE / NIEDOSTEPNE:** nie mozna tutaj budowac.
  Przy kliknieciu nie sa pobierane materialy.
- Siatka aktualizuje sie przy przesuwaniu myszy; znika po zbudowaniu
  konstrukcji, anulowaniu Esc/PPM lub opuszczeniu trybu budowania.

Ograniczenie zajetosci jest **wspolne dla wszystkich konstrukcji**:
centrum dowodzenia (B), modul rekultywacji (L), huta (H),
panel sloneczny (V), akumulator (K) i kopalnia (M). Walidacja uwzglednia
caly obrys z marginesem, drzewa, zloza, magazyn, rakiete, stacje ladowania,
inne budynki i aktualne polozenie robotow. Nie mozna wiec zbudowac np.
panelu slonecznego bezposrednio na hucie, nawet jesli kursor wskazuje grunt
pod budynkiem. **Kopalnia** nadal wymaga konkretnego zloza zelaza;
jest to jedyny dozwolony wyjatek od zakazu zabudowy zloz.

Siatka jest wyswietlana przez MultiMesh (`scripts/build_placement_preview.gd`)
i nie posiada kolizji. Weryfikacja w `scripts/main.gd` korzysta
z tej samej informacji o zajetosci terenu co wyswietlanie podgladu,
wiec nie ma rozbieznosci miedzy kolorem a mozliwoscia postawienia budynku.
Test regresyjny: `tests/build_placement_smoke.gd`.

**Test reczny:** wybierz V, przesun kursor nad magazyn (czerwony obrys),
a nastepnie na puste pole (zielony). Nacisnij Esc i powtorz test dla
centrum B, huty H oraz akumulatora K. Sprawdz rowniez M nad zelazem.

## WOW 0.9 — rozbudowa sieci energetycznej i pracujace maszyny

Ta aktualizacja dodaje budowane instalacje energetyczne i animacje
przemyslowe. Zachowane zostaly Mars / Ziemia / Kepler, rakieta,
roboty, huta, kopalnia i transport tasmociagami.

### Nowe konstrukcje

| Obiekt | Sterowanie | Materialy | Parametry |
|---|---|---|---|
| Obrotowy panel PV | **V**, nastepnie LPM | 8 metalu + 5 kamienia | +4 kW generacji |
| Magazyn energii | **K**, nastepnie LPM | 12 metalu + 8 kamienia | 8 kWh pojemnosci, max 3 kW ladowanie/rozladowanie |

**Uzycie:** wybierz budynek z klawiatury lub nowego rzedu
przyciskow w dolnym panelu. Wskaz wolny teren LPM. Mozna postawic
do 5 paneli i 3 akumulatorow. Esc lub PPM anuluje budowe.
Nowy budynek otrzymuje widoczny kabel zasilajacy polaczony z rakieta.

**Bilans energetyczny:** istnieje jedna siec kolonii, do ktorej
nowe budowle dolaczaja sie automatycznie. Produkcja z rakiety
(12 kW * jej sprawnosc) sumuje sie z produkcja paneli (+4 kW kazdy).
Stacja ladowania zachowuje priorytet poboru 4 kW, nastepnie
kopalnia 1.5 kW, huta 2.5 kW i tasmy 0.15 kW na sztuke.
Gdy energii brakuje, bank moze rozladowac zapas z moca do 3 kW.
Gdy produkcja przewyzsza pobor, magazyn laduje sie z nadwyzki.
Dla zauwazalnej rozgrywki **1 sekunda w grze = 1 minuta
symulowanego magazynowania energii** (8 kWh nie laduje sie
w czasie rzeczywistym). Magazyn zaczyna pusty.
HUD wyswietla moc zrodel, rezerwe oraz poziom energii w bateriach.

### Ruch i efekty wizualne

- **Panel PV** obraca sie w poziomie i zmienia kat nachylenia,
  symulujac dwie osie sledzenia slonca. Mechanizm wykorzystuje
  nasz model Godot oraz element Kenney Factory Kit.
- **Kopalnia** ma wirujaca glowice wiertnicza i ruch posuwisto-zwrotny
  tylko przy dostepnej energii i niewyczerpanym zlozu.
- **Huta** ma wirujacy wentylator i kilkanascie lecacych iskierek
  nad paleniskiem. Iskry pojawiaja sie **tylko podczas przetapiania**.
- **Kable** sa polozone na powierzchni i maja ruchome turkusowe
  impulsy swiatla. Nie tworza przeszkod dla robotow.
- Do modeli kopalni, huty i energetyki dodano oryginalne detale
  **Kenney Factory Kit CC0** z folderu `assets/kenney/factory/`.

W scenie `scenes/asset_showroom.tscn` (otworz i uruchom **F6**)
znajdziesz obrotowy panel, magazyn energii, kabel oraz pracujacy
wiertak i hute z iskrami.

### Test gry

1. `git pull origin main`, uruchom Godot i gre przez **F5**.
2. Zbuduj kopalnie (M) i hute (H), poczekaj na pierwsze sztabki metalu.
3. Gdy bedzie co najmniej **8 metalu i 5 kamienia**, nacisnij **V**,
   kliknij teren i obserwuj ruch PV. Moc na HUD powinna wzrosnac
   o 4 kW.
4. Gdy bedzie **12 metalu i 8 kamienia**, nacisnij **K**,
   kliknij teren i obserwuj wzrost poziomu magazynu.
5. Obejrzyj dzialajaca hute z bliska obracajac kamere **Q/E**
   i przyblizajac kolkiem myszy.

**Zakres prototypu:** kable sa widoczne, ale nie ma jeszcze
edytora recznego okablowania, lokalnych awarii przewodow ani
dnia/nocy wplywajacego na uzysk z PV. Silniki i iskry sa
autorskimi animacjami Godot bez pobierania efektow z zewnatrz.

Nowe skrypty: `solar_array.gd`, `battery_bank.gd`,
`power_cable.gd`, `industrial_fx.gd`; test:
`tests/power_grid_smoke.gd`.

## WOW 0.8 — polaczenia od maszyny do maszyny, rolety i reczne trasy

Wersja poprawia przede wszystkim **czytelnosc logistyczna** fabryki.
Kazda tasma posiada teraz dwie stacje przeladunkowe, doprowadzone do
obrysu kopalni, huty lub magazynu. Znika wizualna przerwa miedzy budynkiem
i pierwszym/ostatnim segmentem A*.

**Detale graficzne** (autorskie meshe Godot):
- laczone ramy, prowadnice w pomaranczowym kolorze, rolki, podpory;
- obrotowe moduly narozy, maskujace szczeliny pod katem 45 i 90 stopni;
- wskazniki przeplywu, turkusowe czujniki na portach wejscia i wyjscia;
- paczki rudy i metalu nadal poruszaja sie realnie po pelnej trasie.

**Budowanie tasmy:**

| Wariant | Sterowanie | Efekt |
|---|---|---|
| Automatyczna ruda | `J` | A* kopalnia → huta (5 metalu) |
| Reczna ruda | `Shift+J` | Wyznacz punkty trasy LPM, zatwierdz Enter |
| Automatyczny metal | `N` | A* huta → magazyn (8 metalu) |
| Reczny metal | `Shift+N` | Wyznacz punkty trasy LPM, zatwierdz Enter |

Przy trasie recznej mozna wskazac do **12 punktow posrednich** na wolnym
terenie. Miedzy punktami silnik sam omija przeszkody za pomoca A*.
Podczas wyboru widoczny jest podglad trasy w turkusowym kolorze.
**Enter** buduje i pobiera materialy, **Esc/PPM** anuluje bez wydatkow.
Jesli trasy nie da sie wyznaczyc, budowa nie nastapi i metal pozostaje
w magazynie. Nadal budujemy jedna tasme na typ polaczenia.

**Kamera:** `Q` i `E` obracaja widok, a `WASD` przesuwaja kamere
zgodnie z jej aktualnym ustawieniem. Kolko myszy kontroluje przyblizenie.

System produkcji i bilans surowcow z WOW 0.7 nie zostaly zmienione.
Porty i prowadnice pozostaja obiektami graficznymi bez nowej kolizji,
aby roboty mogly poruszac sie jak wczesniej.

**Testy:** dotychczasowy `tests/conveyor_smoke.gd` oraz nowy
`tests/conveyor_manual_smoke.gd` (weryfikuje rolety, naroza, porty,
brak kosztu podgladu i poprawny koszt po zatwierdzeniu).
Po aktualizacji warto sprawdzic obie fabryczne tasmy oraz obrocic
kamere Q/E, aby ocenic efekt z kazdej strony.

## WOW 0.7 — pierwsze dzialajace tasmociagi

Po zbudowaniu pierwszej fabryki mozna teraz stopniowo zastapic roboty
transportowe **automatycznymi tasmociagami**. Tasmy sa widoczne na mapie,
prowadzone po trasach A* omijajacych drzewa i budynki. Surowce przesuwaja
sie po nich jako osobne paczki 3D (nie sa tylko zmianami licznika).

**Instrukcja pierwszego uruchomienia:**

1. Zaktualizuj projekt: `git pull origin main`, uruchom F5.
2. Zbuduj kopalnie **M** na zlozu zelaza i hute **H** w poblizu.
3. Pozwol turkusowemu robotowi przewiezc rudy i pierwsze sztabki metalu.
4. Gdy w magazynie bedzie **5 sztabek**, nacisnij **J** (lub przycisk
   `J TASMA RUDY`). Gra automatycznie poprowadzi tasme kopalnia -> huta.
   Robot od tej chwili odbiera metal z huty do magazynu.
5. Gdy uzbierasz dalsze **8 sztabek**, nacisnij **N** (lub przycisk
   `N TASMA METALU`). Gra poprowadzi huta -> magazyn. Cala linia
   kopalnia -> huta -> magazyn moze wowczas dzialac bez transportowca.
6. Nadal mozesz zaznaczyc transportowca i wyznaczyc mu zadanie PPM.

| Tasmociag | Koszt | Pobor mocy | Przepustowosc |
|---|---:|---:|---:|
| Ruda (kopalnia -> huta) | 5 metalu | 0,15 kW | 2 rudy na 0,8 s |
| Metal (huta -> magazyn) | 8 metalu | 0,15 kW | 2 sztabki na 0,8 s |

Paczki przemieszczaja sie z predkoscia **7 jednostek mapy/s**. Produkcja
kopalni i huty zachowuje dotychczasowe tempo. Bufory zrodel sa ograniczone,
wiec wypelniona huta zatrzymuje rozladunek bez utraty materialu.
Przy braku mocy paczki zostaja na tasmie i ruszaja po przywroceniu energii.

Kod: `scripts/conveyor_link.gd`, `scripts/navigation_grid.gd` i integracja
`scripts/main.gd`, `scripts/worker.gd`. Test automatyczny
`tests/conveyor_smoke.gd` sprawdza prowadzenie tasmy, przeplyw rud i metalu,
**bilans masy surowcow**, koszty i odciecie zasilania.

**Ograniczenia prototypu:** obecnie sa dwa automatyczne polaczenia
miedzy konkretnymi budynkami (maks. 95 segmentow), bez recznego
rysowania pojedynczych fragmentow, rozdzielaczy i sortownikow.
Tasmy sa dekoracjami bez kolizji dla robotow. To etap przed
wprowadzeniem pelnej sieci logistycznej typu Factorio.

## WOW 0.6 — pierwsza fabryka (wydobycie, transport, przetop)

Zaimplementowano dzialajacy system kopalnia zelaza -> robot transportowy -> huta
-> magazyn. To pierwszy etap automatyzacji przed przenosnikami i fabrykami.

**Nowe zasoby:**
- Naturalne zloze `iron_ore` z 4500 jednostkami, po prawej stronie mapy.
- Kopalnia wydobywa **4 rudy / 1.5 s**, maksymalnie **80 rudy** w lokalnym buforze.
- Robot transportowy odbiera do **25 jednostek** i dowozi rudy do huty.
- Huta przetwarza **2 jednostki rudy -> 1 sztabka metalu co 3 s**.
- Gotowy metal robot zawozi do magazynu; licznik **METAL** jest na HUD.
- Pozostale zasoby (drewno, zloto, kamien) zachowuja dotychczasowa mechanike.

**Energia kolonii:**
- Na starcie statek ma 70% sprawnosci -> 8.4 kW.
- Stacja ladowania: rezerwacja do 4 kW, jesli jest aktywna.
- Kopalnia: 1.5 kW.
- Huta: 2.5 kW.
- Reszta mocy wyswietlana jako REZERWA w gornym pasku.
- Brak mocy zatrzymuje produkcje maszyny, ale nie kasuje buforow.
- Naprawa statku zwieksza jego dostepna moc.
- Wersja jest uproszczona: jedna siec bazowa, bez osobnych kabli i
  akumulatorow stacjonarnych; budynki liczone sa jako podlaczone do statku.

**Sterowanie i budowa:**
1. Na starcie rakieta ma zapas **90 drewna + 60 kamienia** — materialy
   demonstracyjne na poczatkowy kompleks przemyslowy.
2. Nacisnij **M** (albo przycisk `M KOPALNIA ZELAZA`) i kliknij **LPM na
   zlozu zelaza** w prawej czesci mapy.
   Koszt: 20 drewna + 10 kamienia.
3. Nacisnij **H** (albo `H HUTA METALU`), wybierz LPM miejsce na wolnym
   terenie, najlepiej niedaleko kopalni i magazynu.
   Koszt: 30 drewna + 20 kamienia.
4. Transportowy robot turkusowy zostanie automatycznie przydzielony do
   transportu. Mozesz tez zaznaczyc go i kliknac PPM na kopalni lub hucie,
   zeby ponownie przydzielic trasę.
5. Zaznacz kopalnie albo hute LPM: dolny panel pokazuje stan lokalnego
   zapasu i pobor mocy. Obserwuj licznik METAL po dostawie.
6. Klawisz P nadal przelacza Mars / Ziemia / Kepler bez resetowania fabryki.

**Anulowanie rozkazow:** PPM na ziemi wysyla transportowca w inne miejsce
i zatrzymuje automatyczny kurs. Przy ponownym przydzieleniu PPM na kopalni
robot wznowi cykl.

Ograniczenia: po jednym obiekcie kazdego typu w tej wersji, bez fizycznych
tasmociagow i grafu polaczen energetycznych, bez budowy przez technika
i bez animowanych ladunkow robotow. Zloze zelaza jest ukrywane przez budynek
kopalni, ale ilosc rudy jest rzeczywiscie konsumowana i konczy sie.

Skrypty: `scripts/automated_mine.gd`, `scripts/automated_smelter.gd`,
`scripts/worker.gd` (nowa maszyna stanow robota), `scripts/main.gd`.
Testy: `tests/factory_smoke.gd`, `tests/planet_smoke.gd`.

## WOW 0.5 — trzy planety i nowa oprawa srodowiska

Prototyp moze przedstawic kilka odmiennych swiatow bez przepisywania mechaniki
budowania. **Start: Mars** — ceglasta powierzchnia, pyl, grafitowe skaly,
surowe rosliny terraformacyjne i blado-pomaranczowe oswietlenie.

| Planeta | Klimat wizualny | Kolorystyka i szczegoly |
|---|---|---|
| Mars | Pustynna kolonia / eksperymentalna terraformacja | Rdzawe i ciemne skaly, czerwony pyl, turkusowe uprawy |
| Ziemia | Strefa testowa kolonii | Zielony grunt, zielone drzewa, klasyczne kamienie, jasne niebo |
| Kepler | Obca planeta science fiction (fikcyjna) | Niebiesko-fioletowy grunt, turkusowe krysztaly, fioletowa roslinnosc |

**Klawisz `P` lub przycisk PLANETA na gornym pasku** zmienia wariant w czasie
gry, bez resetowania jednostek i gospodarki. To funkcja do testowania stylistyki:
**nie jest jeszcze podroza rakieta na inna planete**. Docelowo kazda planeta
bedzie miala wlasna mape, rudy, technologia i ograniczenia ekologiczne.

### Ulepszenia wygladu

- Proceduralny shader powierzchni zamiast identycznego koloru i ogromnych
  plaskich plam; warstwy piasku, mineralow i subtelnych pekniec.
- Kenney Nature Kit: pozostaja modele drzew i kamieni (CC0), ale pojawiaja sie
  planetarne barwy roslinnosci, drobne odlamki skalne i charakterystyczne
  krysztaly. Dekoracje **nie blokuja ruchu robotow**.
- Zloto: ciemne rudy z metalicznymi pomaranczowo-zlotymi zylami i krysztalami,
  zamiast jednolicie zoltych skal.
- Kamien: ciemniejsze mineralne formacje i chlodne zlacza.
- Magazyn: autorski industrialny budynek `scripts/depot_model.gd`, platforma
  rozladunkowa, oswietlenie, Kenney Factory Kit skrzynie, bez zmiany kolizji
  magazynu oraz przyjmowania dostaw.
- **Wazne:** siatka nawigacji pozostaje plaska i niezmieniona. Shader i
  dekoracje nie implementuja jeszcze gorskiego terenu ani modelu klimatu.

Kod planety: `scripts/planet_environment.gd`; nowy magazyn:
`scripts/depot_model.gd`. Test nienaruszalnosci gospodarki:
`tests/planet_smoke.gd` (uruchamiany przez GitHub Actions).

### Test po aktualizacji

```bash
git pull origin main
```

Otworz Godot 4.x, poczekaj na import, uruchom F5.
Zobacz Marsa, wybierz robota i wyslij go po zloto. W trakcie transportu
nacisnij P i przelacz planete kolejno na Ziemie i Keplera.
Sprawdz, czy zloze, ladunek i energia robota zachowuja wartosci.
Oceń kontrast drzew, zlota i magazynu w kazdym biomie.
Tryb z planeta jest na razie demonstracja wizualna.

## WOW 0.2 — pierwszy dzien na planecie

Na mapie stoi **rakieta kolonizacyjna** z panelami slonecznymi. Gdy uruchamiasz gre,
z jej rampy wyjezdzaja kolejno trzy samodzielne roboty:

| Robot | Kolor | Pierwsza specjalizacja |
|---|---|---|
| Gornik | Pomaranczowy | Wydobywa 4 jednostki na cykl, przenosi 10 |
| Transportowy | Turkusowy | Transportuje maksymalnie 25 jednostek, laduje 2 na cykl |
| Naprawczy | Zolty | Naprawia statek i stacje ladujaca (PPM na obiekcie) |

**Prototyp transportu:** na razie robot transportowy pobiera surowce bezposrednio
ze zloza i przewozi je do magazynu. W przyszlosci gornik bedzie odkladal material
w magazynie przykopalnianym, a transportowiec obslugiwal osobny lancuch logistyczny.

### Energia

- Statek generuje **do 12 kW energii slonecznej** (zalezy od jego stanu technicznego).
- Na starcie statek ma **70% sprawnosci** — jest to cel naprawy przez technika.
- **Ladowarka** stoi obok statku, ma zasilanie z jego paneli i wymaga 4 kW.
- Roboty posiadaja akumulatory **100 jednostek energii**. Ruch, wydobywanie i naprawy zuzywaja energie.
- Przy **22% energii** robot probuje sam pojechac do ladowarki; po naladowaniu ma wznowic prace.
- **C**: wyslij zaznaczonego robota do ladowarki recznie. Na ekranie widac aktualna energie wybranej jednostki.

To jest poczatek systemu energetycznego; nie ma jeszcze kabli sieciowych do dowolnych
maszyn, baterii stacjonarnych ani bilansowania wielu odbiorcow. Polaczenie rakiety
z ladowarka jest w prototypie stale.

### Zaimportowane modele Kenney — WOW 0.4

Do repozytorium dodano **19 oryginalnych modeli GLB** na licencji CC0:
10 modeli z [Nature Kit](https://kenney.nl/assets/nature-kit)
i 9 modeli z [Factory Kit 3.0](https://kenney.nl/assets/factory-kit).

- Drzewa i zloza na mapie sa teraz modelami Kenney zamiast prostych bryl.
- Skrzynie w magazynie korzystaja z Factory Kit; **mechanika dostaw pozostaje bez zmian**.
- Scena `scenes/asset_showroom.tscn` (F6) pokazuje prawdziwe
  maszyny, tasmiociag, manipulator, drzewa i kamienie Kenney.
- Biblioteka plikow: `assets/kenney/nature/`, `assets/kenney/factory/`.
- Loader: `scripts/kenney_assets.gd`; informacje o licencji i pochodzeniu:
  `assets/kenney/README.md`.

Modele sa obecne fizycznie w repozytorium. Nie trzeba ich osobno pobierac.
Przy pierwszym uruchomieniu Godot moze potrzebowac chwili na import plikow GLB.

**Test:** wykonaj `git pull origin main`, poczekaj na import w edytorze
i uruchom F5. Sprawdz cztery odmiany drzew, zloza zlota i kamienia
oraz skrzynie magazynowe. Roboty powinny nadal zbierac i dostarczac surowce.
Potem uruchom F6 dla `scenes/asset_showroom.tscn`.

Nowe pliki nie zostaly przetestowane w uruchomionym Godocie przez asystenta.

### Przygotowane assety

Ponizsze *wczesniejsze* modele sa **oryginalne, proceduralne** (GDScript: BoxMesh,
CylinderMesh i StandardMaterial3D) i naleza do projektu WOW, bez pobierania platnych
lub cudzych modeli:

- `scripts/colony_lander.gd` — autorska, smukla rakieta wielostopniowa: stozkowa owiewka, centralny korpus, 2 boczne boostery, dysze silnikow, pomaranczowe obręcze, podpory ladowania, niewielkie panele PV i rampa robotow. Stylistyka przemyslowego low-poly, inspirowana ogolna konstrukcja rakiet z Kerbal Space Program (bez kopiowania assetow gry).
- `scripts/charging_pad.gd` — stacja ladowania.
- `scripts/robot_model.gd` — trzy rozne sylwetki robotow.
- `scripts/factory_models.gd` — **wiertnica, tasmociag i huta**; na razie tylko modele.
- `scripts/asset_showroom.gd` — scena wystawowa modeli proceduralnych i nowych modeli Kenney.
- `scripts/town_hall.gd` — futurystyczne centrum dowodzenia (dawny ratusz).
- `scripts/forester_hut.gd` — technologiczny modul rekultywacji (dawna lesniczowka).
- `scenes/asset_showroom.tscn` — otworz ja w Godocie i nacisnij **F6**, aby zobaczyc modele.

**Wazne:** uruchomienie `asset_showroom.tscn` pokazuje modele wizualne. Wiertnica,
tasmociag i huta nie przetwarzaja jeszcze surowcow. Wlasciwa gra startuje w
`scenes/main.tscn`.

## Zmiana kierunku wizualnego rakiety (wzor: klasyczna konstrukcja rakietowa)

Zgodnie z referencjami graficznymi: rakieta ma teraz proporcje nosiciela
wielostopniowego z bocznymi boosterami, zamiast wygladu kapsuly z szeroko
rozstawionymi skrzydlami paneli slonecznych.

- Centralny korpus jest podzielony na dwa stopnie i zwienczony owiewka.
- Dwa boczne boostery maja osobne zbiorniki, mocowania i dysze wylotowe.
- Kolory sa dopasowane do gorniczego robota: grafit, stal, pomarancz i turkus.
- Fotowoltaika pozostaje na pokladzie, ale panele sa zlozone do kompaktowych
  rozmiarow, umieszczone wysoko i nie zmieniaja charakteru rakiety.
- Zasilanie 12 kW, naprawianie statku i wyjazd robotow z rampy pozostaja
  funkcjonalnie bez zmian.

Dla oceny sylwetki uruchom `scenes/asset_showroom.tscn` klawiszem **F6**.
Nowy model wymaga przetestowania w silniku Godot.

## WOW 0.3 — interfejs kolonii i teren

Na podstawie testu ekranowego zmieniono interfejs z plynacych po mapie etykiet
na **stale panele RTS**, tworzone przez `scripts/colony_hud.gd`:

- **Gorny pasek:** nazwa kolonii, drewno, zloto, kamien, populacja oraz moc
  fotowoltaiki i dostepnosc ladowania.
- **Dolny pasek:** podglad zaznaczonego robota (rola, zadanie, ladunek, akumulator),
  karta rakiety/ladowarki i przyciski budowy/produkcji/ladowania.
- Zlikwidowano nachodzace na siebie etykiety 3D oraz blad wyswietlania znakow
  `\\n` zamiast nowych wierszy.
- **Klawisze B/T/L/C** i stare sterowanie PPM/LPM pozostaja aktywne.
- Przygaszono intensywna zielen terenu, dodano mineralne plamy na powierzchni
  i wyszczegolniono miejsce ladowania rakiety.

**Test UI po aktualizacji:** uruchom F5, wybierz gornika, a potem technika.
Sprawdz poziom baterii w dolnym panelu, kliknij LPM na rakiete i ladowarke,
nastepnie z dolnego paska wyslij robota na ladowanie przyciskiem C.
Zbierz surowce i sprawdz, czy przyciski centrum / rekultywacji nadal dzialaja.
Przy zaznaczeniu grupowym dolny panel powinien pokazywac liczbe jednostek.

Nowe zmiany nie zostaly jeszcze zweryfikowane w uruchomionym Godocie w srodowisku asystenta.

## Aktualizacja i test

W folderze sklonowanego repozytorium:

```bash
git pull origin main
```

Otworz `project.godot` w Godot 4.x, nacisnij **F5**. Mozesz rowniez otworzyc
`scenes/asset_showroom.tscn` i uruchomic ja **F6**.

**Test WOW 0.2:**

1. Po wlaczeniu F5 zobaczysz rakiete. Trzy roboty wyjada z rampy kolejno.
2. Zaznacz pomaranczowego robota i kliknij **PPM na drzewie** — ma wydobywac drewno.
3. Turkusowego robota wyslij PPM po zloto; ma dostarczac wieksze ladunki do magazynu.
4. Zaznacz zoltego robota i kliknij **PPM na rakiecie** — wskaznik sprawnosci
   powinien rosnac z 70% do 100%, razem z dostepna moca paneli.
5. Zaznacz robota i nacisnij **C** — powinien pojechac do stacji, naladowac sie,
   a na ekranie powinno rosnac jego wskazanie akumulatora.
6. Otworz scene `asset_showroom.tscn` (F6) — obejrzyj z bliska modele maszyny i robotow.

**Uwaga:** kod jest zapisany w repozytorium, ale nowa wersja wymaga uruchomienia
i sprawdzenia w edytorze Godot na komputerze gracza.

## Sterowanie

| Dzialanie | Sterowanie |
|---|---|
| Wybor robota | LPM |
| Wybor grupy | Przeciagniecie LPM |
| Dodanie do zaznaczenia | Shift + LPM |
| Ruch jednostki | PPM na ziemi |
| Wydobycie | PPM na drzewie / kopalni (gornik lub transportowy) |
| Naprawa | PPM na rakiecie / ladowarce (robot naprawczy) |
| Reczne ladowanie | C |
| Budowa centrum dowodzenia | B, potem LPM na wolnym terenie |
| Szkolenie kolejnego gornika | T |
| Budowa modulu rekultywacji | L, potem LPM na wolnym terenie |
| Anulowanie budowy | Esc / PPM |
| Kamera | WASD, krawedz ekranu, kolko myszy |

## Obecne mechaniki ekonomii

- A* i unikanie przeszkod, transport surowcow do magazynu.
- Zasoby: drewno (200 z drzewa), zloto (3000), kamien (2000).
- Ratusz: 40 drewna + 20 kamienia. Robotnik: 10 drewna + 20 zlota.
- Lesniczowka: 30 drewna + 10 kamienia, sadzenie co 8 sekund, wzrost przez 30 sekund.

## Kolejnosc dalszych prac

1. Przeksztalcic obecny pobor surowcow na **wydobycie wiertnica → bufor przykopalniany**.
2. Oddzielic logistyke od wydobywania: robot transportowy zabiera zapas z buforow.
3. Dodac taśmociagi z automatycznym przesylaniem elementow i hute przetwarzajaca rudy.
4. Zbudowac siec zasilania (generacja, akumulacja, pobor, ograniczenia mocy).
5. Rozbudowac obecny HUD o karte maszyny, kolejki produkcji i stan sieci energetycznej.

## Ograniczenia wersji

- Rakieta **stoi na mapie po ladowaniu**; animacja jej lotu to kolejny etap.
- Nie ma jeszcze prawdziwego montazu robotow przez konstruktor i fizycznego podnoszenia
  ladunkow manipulatorami.
- Wiertnica, tasmociag i huta sa **wylacznie assetami wizualnymi**.
- Brak kolizji i wzajemnego omijania poruszajacych sie robotow.
- Naprawy w prototypie zuzywaja energie robota, ale nie czesci zamienne.
- Brak zapisu gry i obcego zagrozenia.
