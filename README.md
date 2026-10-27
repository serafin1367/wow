# WOW — robotyczna kolonia (Godot 4.x)

WOW to prototyp ekonomicznej gry strategicznej 3D z kamera RTS.
Celem jest rozwoj **samowystarczalnej kolonii robotow na obcej planecie**.
Inspiracja gatunkiem: automatyzacja produkcji i logistyka; oprawa wizualna jest nasza, tworzona w Godot z proceduralnych meshow low-poly.

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

### Przygotowane assety

Wszystkie ponizsze modele sa **oryginalne, proceduralne** (GDScript: BoxMesh,
CylinderMesh i StandardMaterial3D) i naleza do projektu WOW, bez pobierania platnych
lub cudzych modeli:

- `scripts/colony_lander.gd` — autorska, smukla rakieta wielostopniowa: stozkowa owiewka, centralny korpus, 2 boczne boostery, dysze silnikow, pomaranczowe obręcze, podpory ladowania, niewielkie panele PV i rampa robotow. Stylistyka przemyslowego low-poly, inspirowana ogolna konstrukcja rakiet z Kerbal Space Program (bez kopiowania assetow gry).
- `scripts/charging_pad.gd` — stacja ladowania.
- `scripts/robot_model.gd` — trzy rozne sylwetki robotow.
- `scripts/factory_models.gd` — **wiertnica, tasmociag i huta**; na razie tylko modele.
- `scripts/asset_showroom.gd` — scena wystawowa wszystkich modeli.
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
5. Rozbudowac UI: karta maszyny, produkcja, kolejki, stan sieci energetycznej.

## Ograniczenia wersji

- Rakieta **stoi na mapie po ladowaniu**; animacja jej lotu to kolejny etap.
- Nie ma jeszcze prawdziwego montazu robotow przez konstruktor i fizycznego podnoszenia
  ladunkow manipulatorami.
- Wiertnica, tasmociag i huta sa **wylacznie assetami wizualnymi**.
- Brak kolizji i wzajemnego omijania poruszajacych sie robotow.
- Naprawy w prototypie zuzywaja energie robota, ale nie czesci zamienne.
- Brak zapisu gry i obcego zagrozenia.
