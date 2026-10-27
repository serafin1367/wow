# WOW — modele Kenney (Creative Commons Zero)

W projekcie umieszczono **19 rzeczywistych plikow `.glb`**, a nie atrapy ani
skrypty pobierajace brakujace dane przy uruchamianiu.

## Zawartosc

- `nature/` — 10 obiektow z **Kenney Nature Kit**: oak/default/cone/pine,
  4 kamienie, trawa i stos klod.
- `factory/` — 9 obiektow z **Kenney Factory Kit 3.0**: tasma prosta,
  narożnik, rozgalezienie T, maszyny, pudla, lej zsypowy i ramie robota.
- `factory/Textures/colormap.png` — wspolna tekstura barw Factory Kit, wymagana
  przez importowane GLB; bez niej maszyny moglyby utracic kolory.

## Autorzy i licencje

**Autor modeli: Kenney (https://kenney.nl)**

- Nature Kit: https://kenney.nl/assets/nature-kit
- Factory Kit: https://kenney.nl/assets/factory-kit
- Licencja obu zestawow: [Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/).
- Wykorzystanie i rozpowszechnianie, takze w grach komercyjnych, jest dozwolone.
  Kenney nie wymaga podania autora, ale zachowujemy informacje o pochodzeniu.

## Kopie zrodlowe wykorzystane do wprowadzenia plikow

Pobranie oficjalnych archiwow Kenney nie bylo mozliwe w srodowisku integracyjnym.
To jednak te same otwarte modele Kenney, odczytane z repozytoriow udostepniajacych
je pod licencja CC0 i zachowujacych pierwotne nazwy:

- Nature Kit: https://github.com/Hidencod/tge-assets
  (`packs/nature-kit/*.glb`, ten sam pakiet z 329 modelami).
- Factory Kit: https://github.com/levinzonr/godot-asset-placer
  (`demo/assets/kenney_factory_kit/GLB format/*.glb`, zestaw Kenney Factory Kit).

Dla kazdego modelu zachowano oryginalne zakodowane bajty GLB, bez zmian w siatkach.
Modele sa ladowane przez `res://scripts/kenney_assets.gd` z kopiowanych do gry
plikow — brak pobierania podczas rozgrywki.

## Uzycie w grze

- `scripts/main.gd`: cztery odmiany drzew, kamienne i zlote zloza,
  skrzynie w magazynie; licznik zasobow i kolizje niezmienione.
- `scripts/asset_showroom.gd`: modele Factory Kit oraz przyrody
  jako galeria porownawcza (otworz `scenes/asset_showroom.tscn`, F6).
- Modele fabryczne **nie maja jeszcze logiki produkcyjnej ani automatycznych
  tasmiociagow**; na razie sa tylko grafika.

## Uwagi dotyczace skali

Kenney Nature Kit ma mniejsza skale jednostek niz nasza scena 3D,
dlatego drzewa sa tymczasowo wyswietlane w skali x3.8, a kamienie x3.
Kolizje pozostaly na istniejacych obiektach `StaticBody3D`; ich rozmiary
sprawdzimy i dostroimy w Godocie po ocenie sceny.
