# WOW — prototyp strategii czasu rzeczywistego

Autorska gra RTS 3D inspirowana mechaniką klasycznych strategii. Silnik: **Godot 4.x**, język: **GDScript**, platforma docelowa: Windows.

## Co jest już zaimplementowane

- Płaski teren 3D: 100 × 100 jednostek.
- Kamera RTS: WASD, przesuwanie przy krawędziach okna, zoom kółkiem myszy.
- Trzech robotników (modele zastępcze).
- **LPM**: wybór jednej jednostki.
- **Przeciągnięcie LPM**: zaznaczenie prostokątem wielu jednostek.
- **Shift + zaznaczanie**: dodawanie do aktualnego wyboru.
- **PPM**: wydanie rozkazu ruchu zaznaczonym jednostkom.
- **AStarGrid2D**: planowanie trasy wokół drzew i dwóch złóż surowców.
- 10 drzew, kopalnia złota i kamieniołom (jeszcze bez wydobycia).

## Uruchomienie

1. Sklonuj repozytorium: `git clone https://github.com/serafin1367/wow.git`
2. Jeśli projekt jest już otwarty w Godocie, pobierz zmiany poleceniem `git pull`, gdy gra jest zatrzymana.
3. W Godot 4 otwórz projekt wskazując `project.godot`.
4. Uruchom **F5**. W razie problemów sprawdź zakładki **Output** i **Debugger**.

## Test ręczny

1. Zaznacz pojedynczego robotnika i wyślij go PPM na inne miejsce mapy.
2. Przeciągnij LPM wokół wszystkich trzech robotników; każdy powinien mieć zielone obramowanie.
3. Wydaj rozkaz PPM po drugiej stronie grupy drzew albo kopalni. Robotnicy powinni przejść do punktu wyznaczoną trasą, zamiast przechodzić przez przeszkody.
4. Sprawdź, czy **Shift + LPM** dodaje kolejnego robotnika do zaznaczenia.

> Implementacja A* opiera się na uproszczonej, dyskretnej siatce terenu. Nie ma jeszcze lokalnego unikania zderzeń między jednostkami, animacji ani zbierania zasobów. Aktualna wersja czeka na test uruchomieniowy w Godocie.

## Struktura

- `project.godot` — ustawienia.
- `scenes/main.tscn` — scena startowa.
- `scripts/main.gd` — teren, drzewa, kopalnie, sterowanie.
- `scripts/rts_camera.gd` — kamera RTS.
- `scripts/worker.gd` — zachowanie jednostki i przechodzenie po punktach trasy.
- `scripts/navigation_grid.gd` — A* oraz pola zablokowane.
- `scripts/selection_box.gd` — podświetlenie prostokąta zaznaczenia.

## Następne kroki

1. Przetestować nową wersję i usunąć ewentualne błędy.
2. Rozbudować selekcję (ikony, panel jednostek, grupy pod klawiszami).
3. Dodać pozyskiwanie drewna, złota i kamienia oraz magazyn zasobów.
4. Dodać bazę, budynki, produkcję jednostek.
5. Opracować dwie autorskie frakcje.
