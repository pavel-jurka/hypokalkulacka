# Hypoteční Kalkulačka

iPad aplikace pro simulaci investice do nemovitosti na hypotéku. Umožňuje interaktivně modelovat celý průběh hypotéky rok po roku — vidíte přesně, kolik platíte na úrocích, kolik přináší nájem a jaký je váš čistý výsledek v každém okamžiku.

## Požadavky

- iPadOS 17 nebo novější
- Xcode 15+

## Funkce

### Vstupy (levý panel)

| Sekce | Parametr | Výchozí hodnota |
|---|---|---|
| Nemovitost | Cena nemovitosti | 12 875 000 Kč |
| Nemovitost | Vlastní kapitál | 10 % (1 287 500 Kč) |
| Hypotéka | Délka | 20 let |
| Hypotéka | Úroková sazba | 4,50 % |
| Příjmy | Měsíční nájem | 30 000 Kč |
| Příjmy | Roční růst nájmu | 2,00 % |
| Opravy | Roční údržba | 130 000 Kč |
| Opravy | Velká údržba každých N let | 10 let / 300 000 Kč |

Všechny hodnoty jsou ovládány slidery — změna okamžitě přepočítá celý harmonogram.

Aplikace průběžně zobrazuje:
- **Měsíční splátku** (vypočítaná ze vzorce, nelze zadat ručně)
- **Bod zvratu** — první rok, kdy kumulativní čistý výsledek přejde do plusu
- **Čistý výsledek za celou dobu** hypotéky

### Mimořádné splátky jistiny

Lze přidat libovolný počet jednorázových splátek jistiny v konkrétním roce:

1. Zvolte rok Stepperem (1 — délka hypotéky)
2. Nastavte výši splátky sliderem (10 000 — 3 000 000 Kč, krok 10 000 Kč)
3. Klikněte **Přidat mimořádnou splátku**

Každá splátka má **toggle** — lze ji dočasně vypnout bez smazání. To umožňuje porovnat scénáře (např. "co kdybych v roce 5 zaplatil navíc 500 000 Kč?") pouhým přepnutím.

Pokud mimořádné splátky hypotéku zkrátí, zobrazí se rok předčasného splacení.

### Snapshot (kumulativní přehled ke zvolenému roku)

Slider v horní části pravého panelu umožňuje "cestovat v čase" — posunete ho na libovolný rok a okamžitě vidíte kumulativní hodnoty k tomuto roku.

**Se započtením vlastního kapitálu:**

| Karta | Popis |
|---|---|
| Splátky celkem | Součet všech pravidelných + mimořádných splátek |
| z toho úroky | Kolik z výše zaplacených peněz byly čistě úroky (náklad) |
| Zbývající dluh | Nesplacená jistina na konci zvoleného roku |
| Příjmy z nájmu | Kumulativní příjmy z nájmu (s ročním růstem) |
| Čistý výsledek | Výsledek zahrnující počáteční vklad vlastního kapitálu |

**Bez vlastního kapitálu (čistý tok peněz):**

| Karta | Popis |
|---|---|
| Zaplaceno na splátkách | Totéž co výše |
| Příjmy z nájmu | Totéž co výše |
| Nájem − splátky | Kladné = nájem pokrývá splátky s přebytkem |

### Grafy

Přepínačem **Graf / Tabulka** v pravém panelu volíte zobrazení.

#### 1. Kumulativní čistý výsledek
Linie ukazující celkový výsledek investice od prvního dne. Červená = v mínusu, zelená = v plusu. Indigo svislá čára označuje zvolený rok ze snapshotu.

> **Co zahrnuje:** −vlastní kapitál + nájem − úroky − opravy − mimořádné splátky  
> **Co nezahrnuje:** hodnotu nemovitosti, daně z příjmu, ušlý výnos alternativní investice

#### 2. Složení splátky: jistina vs. úroky
Normalizované sloupce (100 %). Na začátku hypotéky tvoří úroky většinu každé splátky, ke konci naopak. Vizuálně ukazuje, kolik z vaší splátky skutečně snižuje dluh a kolik je čistý náklad.

#### 3. Zbývající dluh a celkové úroky
Dvě samostatné linie na stejné ose:
- **Modrá (klesající)** — zbývající nesplacená jistina
- **Červená (stoupající)** — kumulativní suma zaplacených úroků

Průsečík těchto dvou čar říká: *„od tohoto roku jsi na úrocích zaplatil víc, než ještě dlužíš."*

#### 4. Čistý výsledek po letech
Sloupce za každý rok: `nájem − úroky − opravy`. Ikonka klíče označuje roky velké údržby. Červené sloupce = v daném roce jste dopláceli z vlastní kapsy.

### Tabulka

Rok po roku zobrazuje všechny výpočtené hodnoty:

| Sloupec | Popis |
|---|---|
| Rok | Číslo roku; klíč = rok velké údržby |
| Úroky | Část splátky jako náklad (červeně) |
| Mim. splátka | Mimořádná splátka jistiny, pokud byla zadána (fialově) |
| Jistina | Část splátky snižující dluh |
| Zbývající dluh | Nesplacená jistina na konci roku (oranžově) |
| Příjmy z nájmu | Skutečný příjem daného roku (roste s inflací nájmu) |
| Opravy | Celkové roční náklady na údržbu; tučně v roce velké opravy |
| Čistý rok | Nájem − úroky − opravy |
| Kumulativní | Celkový výsledek od začátku investice |

## Výpočetní model

### Anuitní splátka
Měsíční splátka se počítá standardním vzorcem pro anuitu:

```
M = P × r × (1+r)^n / ((1+r)^n − 1)
```

kde `P` = výše hypotéky, `r` = měsíční úroková sazba (`roční sazba / 12`), `n` = celkový počet měsíců.

### Roční příjem z nájmu
Nájem roste každý rok geometricky:

```
nájem(rok) = měsíční_nájem × 12 × (1 + růst/100)^(rok−1)
```

### Kumulativní čistý výsledek
Počáteční hodnota = −vlastní kapitál. Každý rok se přičítá:

```
Δ = příjem_z_nájmu − zaplacené_úroky − opravy − mimořádná_splátka
```

Splátka jistiny (principalPaid) se **nezapočítává** — peníze neopouštějí váš majetek, pouze přecházejí z cashflow do vlastního kapitálu v nemovitosti.

### Mimořádné splátky
Aplikují se vždy na konci roku po pravidelných splátkách. Nemohou přesáhnout zbývající jistinu. Po úplném splacení se generují roky bez splátek — čistý příjem = nájem − opravy.

## Architektura kódu

```
ContentView.swift
├── ExtraPayment          — datová struktura pro mimořádnou splátku
├── YearData              — výsledek pro jeden rok (read-only)
├── MortgageViewModel     — @Observable; vstupy + veškerá výpočetní logika
├── czk()                 — helper pro formátování částek v Kč
├── ContentView           — kořenový view (NavigationSplitView)
├── InputPanel            — levý panel, všechny slidery a vstupy
├── SliderRow             — znovupoužitelný řádek se sliderovou kontrolou
├── DetailPanel           — pravý panel, přepíná Graf ↔ Tabulka
├── SnapshotHeader        — slider roku + dvě sady karet s kumulativními hodnotami
├── SnapCard              — jednotlivá informační karta v SnapshotHeader
├── ChartPanel            — ScrollView se čtyřmi grafy (Charts framework)
└── YearTable             — Table view s amortizačním harmonogramem
```

**Klíčová technická rozhodnutí:**
- `@Observable` místo `ObservableObject` — vyžaduje iOS 17, eliminuje potřebu `@Published`
- `series:` parametr v `LineMark` — nutný pro správné vykreslení více čar v jednom `Chart`; bez něj Charts spojuje body všech sérií do jedné a vzniká zubatý vzor
- `chartForegroundStyleScale` — jedině tato metoda generuje legendu v grafu; přímé `.foregroundStyle(Color.X)` legendu nevytvoří
- Amortizační harmonogram se vypočítává jako computed property (ne cache) — přepočet je dostatečně rychlý i při 30 letech × 12 měsíců = 360 iteracích

## Co aplikace nezohledňuje

- Daň z příjmu z nájmu
- Pojištění nemovitosti a domácnosti
- Poplatky za správu (realitní agentura)
- Změnu úrokové sazby v průběhu fixace
- Zhodnocení nebo znehodnocení nemovitosti v čase
- Ušlý výnos z vlastního kapitálu (alternativní investice)
