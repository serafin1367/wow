# WOW — prototyp strategii czasu rzeczywistego

Autorski RTS 3D na **Godot 4.x / GDScript**, docelowo dla Windows. Grafika jest tymczasowa i nie korzysta z zewnętrznych assetów.

## Gotowe funkcje

- Mapa 3D 100 × 100 z kamerą RTS (WASD, krawędzie ekranu, kółko myszy).
- Zaznaczanie pojedynczych i wielu jednostek; rozkazy ruchu i zbierania.
- Pathfinding `AStarGrid2D`: robotnicy omijają drzewa, kopalnie i ratusz.
- **Drewno, złoto i kamień** — złoża są ograniczone. W prototypie każde drzew ma **200 drewna**, kopalnia **3000 złota**, a kamieniołom **2000 kamienia**. Po wyczerpaniu złoże znika; robotnik szuka następnego źródła tego samego surowca (jeśli jest dostępne).
- Automatyczne zbieranie surowców: robotnik ładuje maksymalnie 10 jednostek i dostarcza je **do punktu obok magazynu**, nie przechodzi przez magazyn.
- Liczniki surowców i populacji robotników.
- **Ratusz:** stawianie po zebraniu **40 drewna i 20 kamienia**.
- **Produkcja robotnika:** koszt **10 drewna i 20 złota**, czas szkolenia **4 sekundy**, limit populacji **30**. Robotnicy pojawiają się na wolnych polach po stronie ratusza bliższej kamerze, bez nakładania się na inne jednostki; nowy robotnik dostaje na chwilę napis nad głową.
- Na razie można zbudować **jeden** ratusz; budowa odbywa się natychmiast po wskazaniu miejsca.
- **Leśniczówka:** koszt **30 drewna i 10 kamienia**, maksymalnie **4 budynki**. Co **8 sekund** sprawdza wolne miejsca w promieniu **17** jednostek. W obszarze utrzymuje najwyżej **12 żywych drzew i sadzonek**.
- **Sadzonki:** rosną **30 sekund**. Dopiero dojrzałe drzewa dają 200 drewna i blokują drogę. Jeśli w chwili dojrzewania na drzewie stoi robotnik, nadanie kolizji zostaje opóźnione.
- **Odnowa lasu:** po wycięciu drzewa leśniczówka może posadzić nowe; bez leśniczówki las nie odrasta. Robotnicy czekający na drewno wznawiają pracę po pojawieniu się dojrzałego drzewa.

## Instalacja / aktualizacja

Sklonuj repozytorium:

```bash
git clone https://github.com/serafin1367/wow.git
```

Jeśli projekt jest już na dysku: zatrzymaj grę i pobierz najnowszy kod z katalogu repozytorium:

```bash
git pull origin main
```

Otwórz `project.godot` w Godot 4 i naciśnij **F5**.

## Sterowanie

| Akcja | Klawisz / przycisk |
|---|---|
| Zaznaczenie jednostki | LPM |
| Zaznaczenie prostokątem | Przeciągnięcie LPM |
| Dodanie do zaznaczenia | Shift + LPM / Shift + przeciągnięcie |
| Rozkaz ruchu | PPM na ziemi |
| Zbieranie | PPM na drzewie, złocie lub kamieniu |
| **Budowa ratusza** | **B** lub przycisk „Ratusz”, następnie LPM na wolnym terenie |
| **Produkcja robotnika** | **T** lub przycisk „Robotnik” po wybudowaniu ratusza |
| **Budowa leśniczówki** | **L** lub przycisk „Leśniczówka”, następnie LPM na wolnym terenie |
| Anulowanie trybu budowy | Esc / PPM |
| Ruch kamery | WASD lub krawędzie ekranu |
| Przybliżenie / oddalenie | Kółko myszy |

## Test ręczny: budowanie i produkcja (wersja do sprawdzenia w Godocie)

1. Wyślij robotnika do drzew oraz drugiego do kamieniołomu. Poczekaj na **40 drewna i 20 kamienia** w magazynie.
2. Wciśnij **B** lub przycisk ratusza. Kliknij LPM na pustej ziemi, z dala od magazynu, jednostek i złóż.
3. **Ratusz** powinien pojawić się na mapie. Liczniki drewna i kamienia powinny spaść o koszt budowy.
4. Zbierz **10 drewna i 20 złota**. Naciśnij **T** lub przycisk „Robotnik”.
5. Po około **4 sekundach** nowy robotnik powinien pojawić się obok ratusza. Liczba jednostek powinna wzrosnąć z **3 do 4**.
6. Sprawdź, czy nowy robotnik może poruszać się i zbierać surowce tak jak pozostałe jednostki.
7. Spróbuj postawić ratusz na kopalni, zbyt blisko magazynu albo bez surowców — mechanizm powinien odrzucić taki rozkaz.

## Test ręczny poprawek widoczności i kolizji

1. Po zebraniu wymaganych surowców postaw ratusz i wyszkol kilka jednostek. Sprawdź, czy pojawiają się **przed ratuszem względem aktualnego ustawienia kamery** oraz czy nowe postacie nie stoją jedna na drugiej.
2. Zleć trzem robotnikom wydobywanie różnych surowców. Po zebraniu 10 jednostek powinni podejść do **obrzeża magazynu**, a nie przenikać przez skrzynie.
3. Wyślij jednostki PPM na środek ratusza i magazynu. Powinny dojść do najbliższego osiągalnego pola **obok** budynku.
4. Pozwól robotnikowi wyczerpać drzewo. Drzewo powinno zniknąć, a robotnik — jeśli ma inne drzewa na mapie — wybrać kolejne źródło drewna.
5. Sprawdź licznik surowców, także gdy kilku robotników jednocześnie oddaje ładunek.

**Uwaga:** To zestaw poprawek po testach gracza; nie był uruchamiany w Godocie w środowisku automatycznym. Prosimy o zgłaszanie błędów z zakładki Debugger.

## Test ręczny: odnawianie lasu

1. Zbierz przynajmniej **30 drewna i 10 kamienia**.
2. Naciśnij **L** (albo przycisk Leśniczówka) i kliknij wolne miejsce blisko lasu, lecz z zapasem miejsca wokół budynku.
3. Po około **8 sekundach** powinna pojawić się pierwsza mała sadzonka, jeśli w obszarze jest miejsce i mniej niż 12 aktywnych drzew/sadzonek.
4. Obserwuj jej wzrost przez około **30 sekund**; wcześniej robotnicy nie powinni móc jej ścinać.
5. Po wyrośnięciu kliknij PPM na koronie: robotnik powinien zbierać drewno i dostarczać je do magazynu.
6. Gdy drzewo zostanie wycięte, leśniczówka powinna móc posadzić kolejne. Wyślij robota do drewna i sprawdź, czy po wyczerpaniu całego lasu wznowi pracę, gdy nowe drzewo dojrzeje.

**Nowa funkcja nie została jeszcze przetestowana w uruchomionym Godocie.**

## Struktura skryptów

- `scripts/main.gd` — mapa, sterowanie, surowce, budowanie, szkolenie, HUD.
- `scripts/town_hall.gd` — model ratusza i kolizje budynku.
- `scripts/forester_hut.gd` — model leśniczówki i zegar nasadzeń.
- `scripts/worker.gd` — ruch i cykl zbierania/dostarczania.
- `scripts/resource_node.gd` — zasoby z ograniczoną pojemnością.
- `scripts/navigation_grid.gd` — trasy A* i zablokowane pola.
- `scripts/rts_camera.gd` — kamera.
- `scripts/selection_box.gd` — zaznaczanie wielu jednostek.

## Ograniczenia

- Nowe mechaniki budowania i szkolenia czekają na **test działania w edytorze Godot**.
- Budowa ratusza jest natychmiastowa: bez animacji pracujących budowniczych i bez czasu budowy.
- Jednostki jeszcze nie unikają siebie nawzajem w trakcie ruchu. Pozycja startowa jednostek jest wybierana z uwzględnieniem zajętych miejsc i kamery.
- Brak zapisu gry, walki i animacji jednostek; drewno odnawia się wyłącznie w zasięgu leśniczówek. Brak odnawiania złota i kamienia.
- Ruch przerywa wykonywanie rozkazu zbierania. Niesiony surowiec zostaje u robotnika, dopóki nie wróci do oddawania materiałów.
- Nie ma jeszcze przeciwników ani frakcji.
- Przy wielu robotnikach nadal brakuje lokalnego omijania innych jednostek. Leśniczówka i las wymagają dodatkowych testów balansu.

## Kolejne etapy

Budowanie innych obiektów (np. koszary), produkcja jednostek bojowych, walka i dwie autorskie frakcje.
