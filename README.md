# WOW — prototyp strategii czasu rzeczywistego

Autorski RTS 3D na **Godot 4.x / GDScript**, docelowo dla Windows. Grafika jest tymczasowa i nie korzysta z zewnętrznych assetów.

## Gotowe funkcje

- Mapa 3D 100 × 100 z kamerą RTS (WASD, krawędzie ekranu, kółko myszy).
- Zaznaczanie pojedynczych i wielu jednostek; rozkazy ruchu i zbierania.
- Pathfinding `AStarGrid2D`: robotnicy omijają drzewa, kopalnie i ratusz.
- **Drewno, złoto i kamień** — ograniczone złoża, które znikają po wyczerpaniu.
- Automatyczne zbieranie surowców: robotnik ładuje maksymalnie 10 jednostek i oddaje je do magazynu.
- Liczniki surowców i populacji robotników.
- **Ratusz:** stawianie po zebraniu **40 drewna i 20 kamienia**.
- **Produkcja robotnika:** koszt **10 drewna i 20 złota**, czas szkolenia **4 sekundy**, limit populacji **30**.
- Na razie można zbudować **jeden** ratusz; budowa odbywa się natychmiast po wskazaniu miejsca.

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

## Struktura skryptów

- `scripts/main.gd` — mapa, sterowanie, surowce, budowanie, szkolenie, HUD.
- `scripts/town_hall.gd` — model ratusza i kolizje budynku.
- `scripts/worker.gd` — ruch i cykl zbierania/dostarczania.
- `scripts/resource_node.gd` — zasoby z ograniczoną pojemnością.
- `scripts/navigation_grid.gd` — trasy A* i zablokowane pola.
- `scripts/rts_camera.gd` — kamera.
- `scripts/selection_box.gd` — zaznaczanie wielu jednostek.

## Ograniczenia

- Nowe mechaniki budowania i szkolenia czekają na **test działania w edytorze Godot**.
- Budowa ratusza jest natychmiastowa: bez animacji pracujących budowniczych i bez czasu budowy.
- Jednostki jeszcze nie unikają siebie nawzajem. Nowe jednostki korzystają z wolnego pola blisko ratusza.
- Brak zapisu gry, walki, animacji oraz automatycznego wybierania kolejnych złóż.
- Ruch przerywa wykonywanie rozkazu zbierania. Niesiony surowiec zostaje u robotnika, dopóki nie wróci do oddawania materiałów.
- Nie ma jeszcze przeciwników ani frakcji.

## Kolejne etapy

Budowanie innych obiektów (np. koszary), produkcja jednostek bojowych, walka i dwie autorskie frakcje.
