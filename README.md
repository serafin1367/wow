# WOW — prototyp strategii czasu rzeczywistego

Autorska gra RTS 3D inspirowana mechaniką klasycznych strategii. Projekt na **Godot 4.x** i **GDScript**, docelowo dla Windows.

## Pierwszy prototyp

- Płaska mapa 3D 100 × 100 jednostek.
- Kamera RTS: WASD, przesuwanie przy krawędziach okna, zoom kółkiem myszy.
- Trzech robotników — tymczasowe modele 3D.
- Wybieranie pojedynczej jednostki lewym przyciskiem; Shift + lewy przycisk dodaje do zaznaczenia.
- Rozkaz przemieszczenia dla zaznaczonych jednostek prawym przyciskiem myszy.
- 10 drzew, złoże złota, kamieniołom — **na razie elementy wizualne**, bez wydobycia i kolizji.

## Jak uruchomić

1. Zainstaluj Godot 4.x.
2. Sklonuj repozytorium `git clone https://github.com/serafin1367/wow.git`.
3. W Godot wybierz **Import**, wskaż `project.godot` i otwórz projekt.
4. Uruchom scenę klawiszem **F6** albo cały projekt **F5**.

## Struktura

- `project.godot` — konfiguracja projektu.
- `scenes/main.tscn` — scena startowa.
- `scripts/main.gd` — generowanie świata, obiekty, zaznaczanie i polecenia.
- `scripts/rts_camera.gd` — kamera.
- `scripts/worker.gd` — robotnik i ruch.

## Następne etapy

1. Test uruchomieniowy w edytorze Godot; naprawa ewentualnych błędów.
2. Wielokrotne zaznaczanie jednostek prostokątem.
3. NavigationMesh + unikanie przeszkód i kolizje obiektów świata.
4. Zbieranie drewna, złota i kamienia, magazyn surowców.
5. Budynki i produkcja jednostek.

> To jest **pierwsza implementacja, niezweryfikowana jeszcze przez uruchomienie Godota**. Dla prostoty ruch prowadzi bezpośrednio do punktu, bez pathfindingu.
