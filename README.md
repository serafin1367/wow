# WOW — robotyczna kolonia (Godot 4.x)

WOW to prototyp ekonomicznej gry strategicznej 3D z kamera RTS.
Celem jest rozwoj **samowystarczalnej kolonii robotow na obcej planecie**.
Inspiracja gatunkiem: automatyzacja produkcji i logistyka; oprawa wizualna jest nasza, tworzona w Godot z proceduralnych meshow low-poly.

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
