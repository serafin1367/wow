# WOW — prototyp strategii czasu rzeczywistego

Autorski RTS 3D na **Godot 4.x / GDScript**, docelowo dla Windows. Grafika jest tymczasowa, bez zewnętrznych assetów.

## Dostępne funkcje

- Mapa 3D 100 × 100 z kamerą RTS (WASD, krawędzie ekranu, kółko myszy).
- Trzy jednostki sterowane prawym przyciskiem myszy, zaznaczanie pojedyncze i grupowe.
- Ruch z wyznaczaniem ścieżek **AStarGrid2D**, omijaniem drzew i złóż.
- **Drewno, złoto i kamień** — złoża mają ograniczoną pojemność i znikają po wyczerpaniu.
- Praca robotników: podejście do surowca, zbieranie, transport maksymalnie **10 jednostek** do magazynu, kolejna wyprawa.
- Magazyn w centrum mapy oraz licznik zgromadzonych zasobów u góry ekranu.
- Rozkaz ruchu do innego miejsca przerywa wykonywane zadanie zbierania.

## Instalacja / aktualizacja

Pobierz najnowszą wersję kodu:

```bash
git clone https://github.com/serafin1367/wow.git
```

Jeśli masz już klon, zatrzymaj grę i wykonaj w katalogu projektu:

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
| Ruch | PPM na ziemi |
| Zbieranie | PPM na drzewie, złocie lub kamieniu |
| Ruch kamery | WASD lub krawędzie ekranu |
| Przybliżenie / oddalenie | Kółko myszy |

## Test ręczny: ekonomia

1. Zaznacz jednego z trzech robotników.
2. Przesuń kamerę w stronę drzew i kliknij **PPM na koronie lub pniu drzewa**.
3. Robotnik powinien dojść do drzewa, zbierać przez kilka sekund, wrócić do **MAGAZYNU** (na środku mapy), a licznik **Drewno** powinien wzrosnąć o 10.
4. Wybierz drugiego robotnika i kliknij PPM na **złożu złota**, trzeciego wyślij do **kamieniołomu**.
5. Zaczekaj, aż wszyscy dostarczą swoje ładunki. Obserwuj trzy liczniki.
6. Spróbuj zaznaczyć grupę i wysłać ją do jednego drzewa. Gdy wyczerpie się jego zasób, obiekt powinien zniknąć i zwolnić drogę.

**Stan testów:** zmian nie uruchomiono jeszcze w silniku Godot w tym środowisku. W razie błędów prześlij komunikaty z zakładki Debugger.

## Struktura skryptów

- `scripts/main.gd` — mapa, wejście myszą, magazyn, ekonomia i HUD.
- `scripts/worker.gd` — rozkazy ruchu oraz cykl zbierania/dostarczania.
- `scripts/resource_node.gd` — zasoby z ograniczoną pojemnością.
- `scripts/navigation_grid.gd` — trasy A* i dynamiczne zwalnianie pól.
- `scripts/rts_camera.gd` — kamera.
- `scripts/selection_box.gd` — zaznaczanie wielu jednostek.

## Ograniczenia

- Nie ma animacji, budowania, produkcji jednostek ani walki.
- Trasy są wyznaczane na płaskiej siatce; brak lokalnego unikania pozostałych robotników.
- Nie ma zapisu gry ani automatycznego przydziału nowych złóż po wyczerpaniu starego.
- Rozkaz ruchu może przerwać transport ładunku; w tej wersji robotnik przechowuje go do kolejnego rozkazu zbierania, kiedy może go odłożyć w magazynie.

## Następny etap

Budowa pierwszego ratusza, produkcja robotników i system kosztów w surowcach.
