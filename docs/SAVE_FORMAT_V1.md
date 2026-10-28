# WOW — kontrakt zapisu JSON v1 (S1 / S2)

**Status:** implementacja na `main`; format `schema_version: 1`.  
**Kod:** `scripts/save_game_manager.gd`.  
**Slot:** `user://wow-save-1.json` (lokalny katalog danych aplikacji Godot).

Dokument jest normatywnym spisem danych zapisu, a nie alternatywnym
menedżerem zapisu. Zmiany formatu wymagają testów zgodności.

## S1 — zakres zapisywanego stanu

| Klucz główny | JSON | Zawartość |
|---|---|---|
| `schema_version` | number | **1**, sprawdzane przed odczytem |
| `planet` | string | `Mars`, `Ziemia`, `Kepler` |
| `resources_total` | object | Nieujemne stany `wood`, `gold`, `stone`, `metal` składu głównego |
| `resources` | array | Drzewa, złoża, pozycja i liczba pozostałych surowców, odrastanie |
| `structures` | array | Kopalnia, huta, centrum, leśniczówka, panele PV, akumulatory, magazyny |
| `robots` | array | Rola, pozycja, energia, stan, ładunek, zadania i trasa |
| `belts` | array | Tryb, punkty trasy, ładunki, przesunięcie paczek na trasie |
| `roads` | object | Siatka zbudowanych dróg |
| `blueprints` | object | Planowane budynki i orientacja |
| `lander`, `charger` | object | Stan rakiety i stacji ładowania |
| `logistics` | object | Zlecenia, priorytety, rezerwacje powiązane z buforami |
| `production_monitor` | object | Liczniki i próbki tempa produkcji |
| `training` | object | Rola, aktywność i czas pozostały szkolenia robota |
| `building_options` | object | Tryb planowania, powtarzania budowy, wielkość siatki |

Wszystkie rekordy trwałych źródeł, budynków, robotów i taśm mają
`save_id` (stabilny identyfikator), `type_id` i
`object_version = 1`. Modele maszyn, magazynów i robotów używają
`to_dict() -> Dictionary` i `from_dict(data: Dictionary) -> void`.
Nowe systemy powinny implementować te operacje od chwili ich wprowadzenia.

**Wektor 3D** to `[x, y, z]`, a obrót budynku zapisuje się liczbowo
jako `rotation_y` w radianach. Dane są typu JSON:
`Dictionary` / `Array` / `String` / `int` / `float` / `bool` /
`null`. **Nie** utrwalamy `Node`, `NodePath`, `RID`,
`ObjectID`, tekstur, `Mesh`, wizualnych instancji paczek,
bezpośrednich referencji między maszynami ani elementów GUI.

Przykładowy **fragment** (niepełny plik stanu gry):

```json
{
  "schema_version": 1,
  "planet": "Mars",
  "resources_total": {
    "wood": 90,
    "stone": 60,
    "gold": 80,
    "metal": 0
  },
  "resources": [],
  "structures": [
    {
      "save_id": "factory:smelter",
      "type_id": "building:smelter",
      "object_version": 1,
      "kind": "smelter",
      "position": [18.0, 0.0, 22.0],
      "rotation_y": 1.5707963267948966
    }
  ],
  "robots": [],
  "belts": [],
  "roads": {"cells": []},
  "blueprints": {"entries": []}
}
```

W produkcyjnym zapisie rekordy budynków zawierają także własne stany
buforów, produkcji i energii. Powyższy fragment służy wyjaśnieniu
typów; nie jest kompletnym snapshotem do wczytania.

## S2 — procedura zapisu i odczytu

1. `SaveGameManager.to_dict(game)` zbiera dane sceny, nie odwołania.
2. `SaveGameManager.validate(snapshot)` weryfikuje wersję, wymagane
   kategorie, dozwolone typy, unikalność `save_id`, poprawność ilości
   oraz podstawową geometrię. **Niepoprawny snapshot nie może
   nadpisać prawidłowego slotu.**
3. `save_file(game)` zapisuje JSON do `user://wow-save-1.json.tmp`,
   zamyka uchwyt i podmienia docelowy plik przez `rename_absolute`.
   Nie zapisujemy do docelowego slotu bezpośrednio.
4. `read_file(path)` odrzuca brak pliku, nieprawidłowy JSON,
   obcą wersję schematu i pliki przekraczające 16 MiB.
5. `from_dict(fresh_scene, data)` odtwarza **nową** scenę:
   planetę, źródła, budynki, drogi, plan budowy, taśmy, roboty,
   a następnie referencje między nimi po `save_id`.
6. Oryginalna rozgrywka jest zastępowana dopiero po pomyślnym
   odtworzeniu; uszkodzony lub niezgodny plik nie może jej usunąć.

`save_id` nie jest nazwał węzła Godota: nazwy mogą ulegać zmianie,
np. podczas powielania drzew. Trwałe ID jest kluczem mapowania,
którego używają również zlecenia logistyczne.

## Zgodność i ograniczenia

- Rozszerzenia w ramach v1 powinny dodawać opcjonalne pola z wartościami
  domyślnymi w `from_dict`; nie zmieniamy znaczenia istniejących pól.
- Zmiana struktury wymaganego pola, usunięcie pola lub nowa semantyka
  wymaga **nowego `schema_version` i migracji**.
- Zapis paczki na taśmie obejmuje jej rodzaj, ilość, kierunek,
  stan doręczenia i odległość; odtworzenie wizualizacji nie pobiera
  surowca po raz drugi.
- Plik jest lokalnym pojedynczym slotem. Brak autosave, wielu slotów,
  archiwizacji i atomowej gwarancji na wszystkich systemach plików.
- Limit odczytu 16 MiB jest ochroną przed nadmiernym użyciem pamięci,
  nie kryptograficznym zabezpieczeniem przed zmodyfikowanym plikiem.

## Testy / kryteria odbioru S1 i S2

- `tests/save_basics_smoke.gd`: identyfikatory i typy JSON v1,
  planeta, podstawowe zasoby, budynki i ich obrót, zapis na dysk
  i odczyt oraz odrzucenie nieprawidłowego formatu.
- `tests/save_load_smoke.gd`: rozbudowany round-trip, roboty,
  energia, projekty, drogi i ładunek w ruchu; brak utraty lub
  podwojenia surowców.
- `.github/workflows/godot-smoke-test.yml`: regresja Linux,
  podstawowy test zapisu również na Windows.

Odbiór w Godot 4.x: zatrzymaj grę **F8**, wykonaj
`git pull origin main`, poczekaj na import, uruchom **F5**.
Użyj **Ctrl+S**, zmień stan kolonii i następnie **Ctrl+O**.
Porównaj planetę, ilości surowców, liczbę i orientację budynków.
