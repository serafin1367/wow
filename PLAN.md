# WOW — plan rozwoju gry (roadmap)

> **Stan bazowy:** WOW 0.12, Godot 4.x, gałąź `main`.
> **Aktualizacja planu:** 28.10.2026.
> **Status dokumentu:** plan prac; niezaznaczone zadania **nie są jeszcze zaimplementowane**.
> **Cel:** grywalna gra RTS/automation o budowaniu robotycznej kolonii, od pierwszego lądowania do samowystarczalnej bazy.

## 1. Co już działa (punkt startowy)

- [x] Kamera RTS, wybór robotów, rozkazy i nawigacja A*.
- [x] Trzy warianty planety: Mars, Ziemia, Kepler (na razie przełączane wizualnie).
- [x] Wydobycie drewna, złota, kamienia i rudy żelaza.
- [x] Kopalnia → transportowiec → huta → magazyn; ruda przetapiana na metal.
- [x] Taśmociągi z paczkami 3D, automatyczne i ręcznie prowadzone trasy.
- [x] Panele fotowoltaiczne, akumulatory, symulowany bilans mocy i przewody.
- [x] Ruchome maszyny, iskry w hucie, modele Kenney (CC0).
- [x] Budowanie z siatką zielone/czerwone, hologramami 3D, obrotem i snapem.
- [x] Drogi techniczne, projekt wielu budynków, budowa seryjna.
- [x] Testy uruchomienia, gospodarki, tras i energetyki w GitHub Actions.

**Istotne ograniczenia wersji 0.12:** brak zapisu stanu gry, pośrednich magazynów i ogólnego systemu zleceń logistycznych; energetyka działa jako uproszczona wspólna sieć, a planety nie są jeszcze osobnymi mapami. Część starszych akapitów README opisuje historyczne wersje.

## 2. Najważniejsza kolejność realizacji

| Kolejność | Etap | Priorytet | Wynik |
|---|---|---|---|
| 1 | **0.13 — zapis/odczyt gry** | P0 | Można przerwać i wznowić rozwój kolonii |
| 2 | **0.14 — logistyka i magazyny** | P0 | Roboty przyjmują zlecenia z wielu budynków |
| 3 | **0.15 — panel produkcji** | P1 | Widać kolejki, tempo produkcji i wąskie gardła |
| 4 | **0.16 — nowe receptury** | P1 | Działa co najmniej drugi łańcuch produkcyjny |
| 5 | **0.17 — sieć energetyczna 2.0** | P1 | Zasilanie zależy od połączeń i magazynowania |
| 6 | **0.18 — sieć taśmociągów 2.0** | P1 | Rozgałęzianie i łączenie niezależnych odcinków |
| 7 | **0.19 — AI i organizacja robotów** | P1 | Stabilna praca wielu jednostek bez ręcznego nadzoru |
| 8 | **0.20 — planety i eksploracja** | P2 | Planeta zmienia zasoby i zasady kolonizacji |
| 9 | **0.21 — UX, balans, samouczek** | P0 przed 1.0 | Nowy gracz potrafi zbudować pierwszą fabrykę |
| 10 | **1.0 — grywalne MVP** | Cel wydania | Stabilny scenariusz budowy samowystarczalnej kolonii |

P0 — blokujące dalszy rozwój; P1 — podstawowe systemy gry; P2 — rozbudowa zawartości. Numery etapów są **propozycją**, nie terminami.

## 3. Zadania szczegółowe

### WOW 0.13 — trwały zapis i odczyt gry (P0) — **ukończony technicznie (odbiór wizualny UI na Windows pozostaje)**

- [x] Wyodrębnić `SaveGameManager` z wersjonowanym formatem danych (`schema_version`).
- [x] Ustalić **wspólny kontrakt serializacji dla wszystkich obiektów utrwalanych w stanie gry**: `to_dict() -> Dictionary` i `from_dict(data: Dictionary) -> void` lub równoważny adapter dla `Resource`. Wymagany od 0.13 także dla **każdego nowego obiektu z etapów 0.14+**, w tym magazynów, portów i zleceń logistycznych; stan nie może zależeć od bezpośredniej serializacji `Node`.
- [x] Zdefiniować stabilne identyfikatory `save_id`, `type_id` i wersje danych obiektów; zapisywać **identyfikatory relacji**, nie ścieżki `NodePath`, instancje węzłów ani referencje w pamięci.
- [x] Odtwarzać scenę **dwuetapowo**: (1) tworzenie obiektów z danych, (2) rozwiązanie relacji po `save_id`, następnie wznowienie symulacji; nie uruchamiać produkcji/transportu podczas częściowego odczytu.
- [x] Dodać ręczny **Zapisz / Wczytaj** oraz co najmniej jeden slot zapisu.
- [x] Odtwarzać planetę, zasoby globalne, pozycję/obrót budynków, zapasy magazynów i rezerwy złóż.
- [x] Odtwarzać roboty, poziom ich energii, ładunki, role oraz bezpiecznie wznowić zadania.
- [x] Zachowywać trasy taśmociągów, paczki w transporcie, drogi, akumulatory i niewykonane projekty.
- [x] Dla każdej paczki na taśmie zapisywać **identyfikator trasy/segmentu, typ i ilość surowca, pozycję logiczną (dystans lub postęp), kierunek oraz stan dostawy**; po odczycie odtwarzać jej pozycję 3D z geometrii trasy, bez polegania na starej transformacji modelu wizualnego.
- [x] Zapisywać atomowo (plik tymczasowy + podmiana) i obsłużyć brak/uszkodzenie pliku.
- [x] Dodać test: **zapis → odczyt → porównanie stanu**, bez utraty lub duplikowania surowców.
- [x] Rozszerzyć `tests/save_load_smoke.gd` o zapis **podczas ruchu paczek** i przy pełnym buforze odbiorcy: po odczycie żadna paczka nie może zniknąć, zawisnąć poza taśmą ani trafić podwójnie do magazynu; animacja ma wznowić ruch z zachowanego postępu. Porównać bilans **wejście + ładunek w drodze + bufory + wyjście** przed/po odczycie.
- [x] Sprawdzić poprawne działanie zapisu na Windows i Linux.

**Kryterium ukończenia:** po ponownym uruchomieniu gry kolonia ma te same budynki, stany magazynowe, roboty i infrastrukturę; produkcja może być wznowiona **bez znikających/duplikowanych paczek i bez osieroconych obiektów 3D**. Nowe encje implementują kontrakt serializacji od chwili powstania. Proponowany plik: `scripts/save_game_manager.gd`, test `tests/save_load_smoke.gd`.

**Potwierdzenie automatyczne:** `tests/save_load_smoke.gd` i cały zestaw testów Godota przeszły na Linuxie i Windows: [GitHub Actions](https://github.com/serafin1367/wow/actions/runs/40680932293). Zapisane są także nieprzetworzone paczki przy pełnym buforze, a zapis wyczerpanego złoża nie uszkadza kopalni. **Do ręcznej weryfikacji:** wygląd przycisków ZAPISZ/WCZYTAJ i wygoda korzystania z nich w oknie gry na Windows.

### WOW 0.14 — magazyny pośrednie i logistyka (P0) — **w trakcie**

**Zrealizowano:** magazyn pośredni `U` (do 3 budynków), magazyny/bufory `Inventory`, wspólne porty kopalni, huty, robotów i taśm, `LogisticsManager` z priorytetami, rezerwacjami i zapisem zleceń w drodze. Zobacz `tests/inventory_smoke.gd`, `tests/logistics_depot_smoke.gd`, `tests/logistics_jobs_smoke.gd` oraz `tests/save_load_smoke.gd`. **Pozostało:** interfejs użytkownika do edycji priorytetów i min./maks. zapasu, bezpieczna zmiana celu przy transporcie, pełna obsługa wszystkich magazynów i długie testy floty.

- [x] Nowy budynek: **depot logistyczny** z ograniczoną pojemnością i kilkoma typami surowca.
- [x] Model ekwipunku dla magazynów i maszyn: wolne miejsce, rezerwacje, pobranie, dostarczenie.
- [x] Zdefiniować **wspólny model portu/buforu wejścia–wyjścia (`Inventory` / `BufferPort`)** dla maszyn, magazynów, robotów i taśmociągów. Ten sam interfejs ma obsługiwać sprawdzenie pojemności, rezerwację, pobranie i przyjęcie ładunku; bez osobnych, rozbieżnych implementacji „dla robota” i „dla taśmy”.
- [x] Zdefiniować jednoznaczne przekazanie własności ładunku: odebrana jednostka znika z bufora źródła **dokładnie raz**, a przyjęta pojawia się w buforze celu **dokładnie raz**. Pełny bufor nie może usuwać ani duplikować ładunku pozostającego na robocie/taśmie.
- [x] Nadać magazynom, buforom, portom i zleceniom stabilne `save_id` oraz kontrakt `to_dict()` / `from_dict()` wdrożony w WOW 0.13.
- [x] Uogólnić zlecenia transportowe: **skąd → co → ile → dokąd**, zamiast sztywnej trasy kopalnia–huta.
- [x] Automatyczny przydział wolnego transportowca do najważniejszego zlecenia.
- [ ] Ustawianie priorytetów zleceń i limitów zapasu (min./maks.) dla magazynów.
- [ ] Obsłużyć brak drogi, pełny magazyn, rozładowany robot, zmianę celu i anulowanie zlecenia.
- [ ] Test wielu magazynów, robotów i taśmociągów korzystających z **tych samych portów**: **każda jednostka ładunku ma dokładnie jednego właściciela**. Zweryfikować również zapis/odczyt z aktywnymi rezerwacjami.

**Stan na 28.10.2026:** automatyczny transfer przez *pierwszy* magazyn i jego serializacja są gotowe; test dwóch równoległych zleceń został dodany. Priorytety i limity magazynowe istnieją jako API, ale nie mają jeszcze panelu ustawień.

**Kryterium ukończenia:** co najmniej dwa równoległe transporty między trzema budynkami nie tracą ani nie powielają surowców; przełączenie odbioru z robota na taśmę **nie wymaga zmiany logiki magazynu**. Proponowane moduły: `Inventory`, `BufferPort`, `LogisticsManager`, `TransportJob`.

### WOW 0.15 — centrum zarządzania produkcją (P1)

- [ ] Panel wybranego budynku: wejście, wyjście, receptura, postęp cyklu, stan energii.
- [ ] Widok całej kolonii: produkcja/min, zużycie/min, dostępne zasoby, obciążenie robotów.
- [ ] Kolejki produkcji z możliwością pauzy i zmiany priorytetu.
- [ ] Czytelne alarmy: brak rudy, pełny bufor, brak transportowca, brak energii.
- [ ] Zaznaczenie i szybkie przejście do budynku wywołującego alarm.
- [ ] Responsywny HUD: bez nakładania paneli na ekranie 1080p i przy mniejszym oknie.

**Kryterium ukończenia:** gracz potrafi z poziomu HUD wskazać, dlaczego fabryka przestała produkować.

### WOW 0.16 — receptury i rozszerzona gospodarka (P1)

- [ ] Zastąpić receptury wpisane na stałe **rejestrem receptur** (wejście, wyjście, czas, moc).
- [ ] Dodać przynajmniej dwa kolejne surowce/produkty (np. stal i element elektroniczny).
- [ ] Dodać warsztat montażu części i jego model/animacje.
- [ ] Wymagać wytworzonych komponentów do części nowych konstrukcji.
- [ ] Zbilansować koszty względem tempa wydobycia i przepustowości taśm.
- [ ] Testy receptur i pełnego bilansu materiałowego.

**Kryterium ukończenia:** drugi łańcuch produkcyjny jest funkcjonalny, nie tylko dekoracyjny.

### WOW 0.17 — energia 2.0 (P1)

- [ ] Graf sieci: generatory, przewody, odbiorniki, akumulatory.
- [ ] Budowanie/obracanie/usuwanie odcinków przewodów; brak połączenia = brak zasilania.
- [ ] Dzień i noc wpływające na moc PV (wspólna symulowana doba).
- [ ] Limity przepływu i priorytety odłączania odbiorników przy przeciążeniu.
- [ ] Panel sieci z produkcją, poborem, prognozą i stanami akumulatorów.
- [ ] Testy odłączenia kabla, zaniku słońca, ładowania/rozładowania i restartu zapisu.

**Kryterium ukończenia:** odcięcie fizycznego połączenia konkretnego budynku zatrzymuje tylko właściwy fragment instalacji.

### WOW 0.18 — taśmociągi 2.0 (P1)

- [ ] Układanie pojedynczych odcinków i zakrętów z hologramem i kontrolą zajętości.
- [ ] Łączenie odcinków w sieć oraz rozgałęziacze, łączenia i kierunki przepływu.
- [ ] Sortowanie surowców oraz wybór wejścia/wyjścia w budynkach.
- [ ] Limit przepustowości, cofanie przy pełnych buforach, przenoszenie paczek między segmentami.
- [ ] Wykorzystać **te same porty wejścia–wyjścia i reguły rezerwacji `Inventory` / `BufferPort` z 0.14**, zamiast tworzyć osobne bufory taśmociągów.
- [ ] Usuwanie/przebudowa fragmentów **bez utraty ładunku**, z zachowaniem poprawności zapisu/odczytu paczek w ruchu.
- [ ] Optymalizacja: instancing i test wielu segmentów oraz paczek.

**Kryterium ukończenia:** jeden ekstraktor może zasilać dwa różne odbiorniki przez rozdzielacz.

### WOW 0.19 — AI robotów i infrastruktura transportowa (P1)

- [ ] Wspólny harmonogram zadań dla górnika, transportowca i technika.
- [ ] Priorytety: awarie, zasilanie/ładowanie, pilne dostawy, zlecenia zwykłe.
- [ ] Ulepszone lokalne unikanie innych robotów i zakleszczeń w wąskich przejazdach.
- [ ] Preferowanie dróg technicznych podczas wyznaczania trasy (koszt ruchu), nie tylko premia do prędkości.
- [ ] Roboty techniczne mogą budować/naprawiać konstrukcje z użyciem części.
- [ ] Testy grupowe: co najmniej 20 aktywnych jednostek bez blokowania całej kolonii.

**Kryterium ukończenia:** kolonia może prowadzić produkcję przy wielu zadaniach bez ciągłego wydawania rozkazów.

### WOW 0.20 — planety i eksploracja (P2)

- [ ] Przenieść palety i zasoby planet do definicji danych (`PlanetDefinition`).
- [ ] Mars, Ziemia i Kepler: inne rozkłady złóż, flora, nasłonecznienie i zagrożenia.
- [ ] Generowanie lub wczytywanie osobnych map planet, niezależnych od bieżącego przełącznika wyglądu.
- [ ] Odkrywanie terenu, znaczniki złóż, czytelna minimapa.
- [ ] Test deterministycznego generowania mapy i odtwarzania jej z zapisu.

**Kryterium ukończenia:** wybór planety naprawdę zmienia warunki gospodarcze, a nie tylko kolor gruntu.

### WOW 0.21 — UX, samouczek i balans (P0 przed 1.0)

- [ ] Menu startowe: nowa gra, kontynuacja, ustawienia i wyjście.
- [ ] Krótki samouczek: złoże → kopalnia → huta → metal → pierwszy taśmociąg.
- [ ] Przyspieszenie czasu, pauza, czytelny komunikat błędu budowy.
- [ ] Podświetlenia portów wejścia/wyjścia, stref zasięgu i problemów logistycznych.
- [ ] Test użyteczności w 1080p na Windows; sprawdzenie klawiszy, tekstów i rozmiaru HUD.
- [ ] Profilowanie CPU/GPU/RAM dla kolonii z wieloma budynkami, robotami i taśmami.
- [ ] Przegląd licencji assetów oraz aktualizacja zdezaktualizowanych fragmentów README.

**Kryterium ukończenia:** nowy gracz bez instrukcji zewnętrznej potrafi uruchomić podstawową produkcję.

## 4. WOW 1.0 — definicja grywalnego MVP

Wersję 1.0 uznajemy za gotową, jeżeli spełnia **wszystkie** warunki:

- [ ] Nowa rozgrywka rozpoczyna się od lądowania na Marsie.
- [ ] Gracz buduje i zasila kolonię oraz co najmniej **dwa łańcuchy produkcji**.
- [ ] Logistyka działa za pomocą robotów, magazynów i rozbudowanych taśmociągów.
- [ ] Gracz może zapisać, zamknąć i wznowić grę bez utraty zasobów.
- [ ] Gra ma zadanie główne: osiągnąć samowystarczalność i wyprodukować wyznaczony zestaw komponentów.
- [ ] Interfejs pokazuje problemy produkcji, energii i transportu.
- [ ] Automatyczne testy GitHub Actions przechodzą; brak krytycznych błędów GDScript.
- [ ] Przetestowany scenariusz gry trwa orientacyjnie 45–60 minut bez konieczności restartu.

**Poza zakresem MVP 1.0:** loty rakietowe między planetami, rozbudowana walka, multiplayer, ogromny otwarty świat i pełna symulacja fizyki. To potencjalne etapy 1.1+.

## 5. Zasady architektury i jakości

1. **Nie rozbudowywać bez końca `scripts/main.gd`.** Nowe systemy tworzyć jako osobne moduły/sceny i łączyć sygnałami.
2. **Jeden model zasobów.** Każde przemieszczenie materiału musi zachować bilans; transfer ma jasny moment pobrania i dostarczenia.
3. **Jedna walidacja budowy.** Drogi, przewody, taśmy, budynki i hologramy korzystają ze wspólnych reguł kolizji/zajętości.
4. **Dane zamiast logiki na sztywno.** Receptury, parametry robotów, budynki i planety definiować jako zasoby konfiguracyjne.
5. **Automatyczne testy.** Każda nowa mechanika ma własny test `--headless`; wszystkie stare testy pozostają zielone.
6. **Bezpieczny zapis jako kontrakt architektoniczny.** Każdy nowy obiekt trwałego stanu implementuje `to_dict() -> Dictionary` / `from_dict(data: Dictionary) -> void` albo wspólny adapter `Resource`. Relacje używają stabilnych `save_id`, a odtwarzanie jest dwuetapowe; **nie serializujemy `Node` ani bezpośrednich referencji**.
7. **Grafika jest funkcjonalna.** Animacja i efekty odpowiadają faktycznemu stanowi produkcji, zasilania lub transportu.
8. **Licencje assetów.** Zachować informacje o źródle i licencji, w szczególności Kenney CC0.
9. **Wspólny interfejs logistyki.** Roboty i taśmociągi używają tego samego `Inventory` / `BufferPort`; w testach musi zgadzać się bilans magazynów, ładunków w drodze i rezerwacji.

**Definicja ukończenia pojedynczego zadania (DoD):** kod w `main`, zielone CI, test regresji, krótka aktualizacja dokumentacji oraz test wizualny w Godot 4 na Windows w przypadku zmian interfejsu lub scen.

## 6. Pierwszy pakiet prac do rozpoczęcia teraz

**WOW 0.13 wykonany i potwierdzony w CI.** Pakiet S1–S7 zrealizowany; kolejne zadanie to integracja `Inventory` / `BufferPort` z kopalnią, hutą, robotami i taśmociągami w WOW 0.14:

- [x] **S1.** Spisać stan gry wymagający serializacji; zdefiniować `schema_version = 1`, stabilne `save_id` i **obowiązkowy kontrakt `to_dict()` / `from_dict()` dla każdego nowego trwałego obiektu (również w 0.14+)**.
- [x] **S2.** Dodać `SaveGameManager` + zapis/odczyt danych podstawowych (planeta, surowce, budynki, obrót) z kontraktem serializacji; **nie utrwalać referencji do `Node`**.
- [x] **S3.** Dodać dwuetapowe odtwarzanie stanów źródeł, energii, robotów, dróg i projektów: najpierw instancje z `from_dict()`, potem rozwiązanie zależności po `save_id`, na końcu wznowienie symulacji.
- [x] **S4.** Dodać taśmociągi i ładunki w drodze: zapisać identyfikator trasy, surowiec, ilość i logiczny postęp paczki; po odczycie odtworzyć pozycję 3D na taśmie. Test `tests/save_load_smoke.gd` musi wykluczać **zniknięcie, zawieszenie w powietrzu lub duplikację paczek**, także przy zablokowanym wyjściu.
- [x] **S5.** Dodać przyciski zapisu/odczytu do HUD/menu i obsługę błędów.
- [x] **S6.** Dodać `tests/save_load_smoke.gd` do GitHub Actions; sprawdzić Windows.
- [x] **S7.** Po zielonym CI oznaczyć etap 0.13 jako ukończony i rozpocząć 0.14.

---

**Ostatnie wykonanie:** 28.10.2026 — WOW 0.13 (zapis/odczyt) oraz początek WOW 0.14 (`Inventory`). Testy Linux + Windows: https://github.com/serafin1367/wow/actions/runs/40680932293.

**Zarządzanie planem:** po zakończeniu każdego etapu oznaczać zadania `[x]`, dopisywać link do commita lub testu i aktualizować priorytety. Nie oznaczać funkcji jako gotowej wyłącznie na podstawie utworzonego pliku — wymagane jest działanie w grze i test.
