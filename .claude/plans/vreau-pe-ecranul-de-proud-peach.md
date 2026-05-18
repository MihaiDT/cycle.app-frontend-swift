# ME tab — Povestea ta / Insightul zilei / Legaturile tale

## Context

Tab-ul ME din HomeView e blank in acest moment: `MeView` randeaza doar `AppleHealthBackground()`, `MeFeature` e stub gol cu un singur delegate `didLogout`, iar subdirectoarele Me au fost sterse complet in sesiunea trecuta. User-ul vrea sa rebuild de la zero ecranul cu trei sectiuni distincte:

1. **Povestea ta** – hero card editorial care prezinta "capitolul" curent generat din date (cicluri, tranzite astrologice, chakre) intr-un text de tip jurnal personal. Continutul real e generat in viitor; acum mock.
2. **Insightul zilei** – box mare centrat in stil Stoic (referinta Mobbin), cu icon, label de faza ciclului, text bold scurt cu italic pe ultimul cuvant, pill outlined "Pastreaza-l", paginatie 3 dots.
3. **Legaturile tale** – card empty-state cu watermark de doua cercuri Venn-intersectate in colt + pill filled cocoa "+ Adauga prima" pentru a invita user-ul sa adauge persoane.

Design-ul a fost validat in 17 iteratii in browser via `/superpowers:brainstorming` + `/ui-ux-pro-max`. Mockup-ul final e `.superpowers/brainstorm/37444-1778580283/content/me-body-sheet-v6.html`. Copy-ul de pe header e "Lorem ipsum dolor." (placeholder de 3 cuvinte) pana decidem direction-ul de tonal voice in alt ciclu.

## Visual decisions confirmate

**Top zone** (full-bleed, no rounded corners):
- Inaltime ~310pt din safeArea top
- Background: `RadialGradient` (peach top-right) overlayed pe `LinearGradient` (170deg, #FFE2CE → #FFCDB0 → #FFBA9A)
- Greeting stanga jos: eyebrow "Marti, 12 mai" (Raleway SemiBold 10pt tracking 0.26em uppercase, color `.accentWarmText`) + titlu "Lorem ipsum dolor." (Raleway ExtraBold 36pt tracking -0.03em, color `.text`, line-height 1.0)
- Stack vertical pe dreapta sus (top: 60pt safe area, right: 18pt, gap 10pt): doua butoane round 42pt:
  - **Avatar**: `LinearGradient(#d99a78, #b06b48)`, litera "M" Raleway Bold 15pt alba
  - **Settings**: white bg cu SF Symbol `gearshape` cocoa, border hairline 0.5px `divider`

**Body sheet** (rises from below):
- Pozitie: top 280pt, full-bleed left/right, extends to bottom
- Background `.background` (#FDFCF7), corner radius 32pt doar top-left + top-right
- Shadow inversa sus: `.shadow(color: .accentWarm.opacity(0.18), radius: 24, y: -6)`
- Padding intern top 16pt, bottom 80pt
- Continut scrollable vertical: section header + card alternand

**Cardurile** (toate radius 22pt, shadow dual `text.opacity(0.08)`/r18/y6 + `text.opacity(0.04)`/r3/y1, border hairline `.divider.opacity(0.5)`):

- **StoryHeroCard** (min-height 168pt, margin horizontal 14):
  - HStack(spacing: 0): illustration zone 120pt cocoa dark gradient (`linearGradient(#5C4A3B → #3A2D24, 160deg)`) cu radial peach overlay `.opacity(0.18)` si line-art alb (doua siluete fata-n fata cu mana intinsa) + content zone flex cu eyebrow "Capitol 04 · Dragostea ta" + titlu Raleway Bold 16pt + body Raleway Regular 11pt secondary

- **DailyInsightCard** (min-height ~250pt, margin 14):
  - VStack centered: ellipsis menu top-right (26pt circle ivory bg), CrescentIcon 32pt centered, label Raleway Medium 12pt secondary, text Raleway Bold 20pt cu ultimul cuvant italic via AttributedString, Spacer, pill outlined "Pastreaza-l" Raleway SemiBold 12pt cu border `text.opacity(0.32)`
  - Sub card: HStack 3 dots paginatie (5pt circle, primul activ 16×5pt `.accentWarm` capsule)

- **BondsCard** (min-height 192pt, margin 14):
  - ZStack(alignment: .topTrailing):
    - VennCirclesWatermark: doua `Circle().stroke(.accentWarm, lineWidth: 2.8).opacity(0.3)` suprapuse (offset orizontal ~26pt), container 178×116pt cu offset `.offset(x: 34, y: -22)` ca sa iasa partial peste edge
    - VStack(alignment: .leading): eyebrow "Cei din jurul tau" + titlu "Vezi cum se asaza relatiile tale." (Bold 17pt) + body "Adauga oamenii care conteaza – observa ce e intre voi." (Regular 11.5pt) + Spacer + pill filled cocoa "+ Adauga prima"
  - `.clipped()` pentru a pastra rotunjirea cardului cand watermark iese

## Files to create / modify

### Modify

**`Packages/Features/Home/Me/MeView.swift`**
Inlocuire completa. Body:
```swift
ZStack {
  Color.bgPagePeach.ignoresSafeArea() // page bg fallback sub body sheet
  VStack(spacing: 0) {
    MeHeaderView(store: store)
    MeBodySheet(store: store)
  }
  .ignoresSafeArea(edges: .top) // header foloseste safe area inset propriu
}
.toolbar(.hidden, for: .navigationBar)
```

**`Packages/Features/Home/Me/MeFeature.swift`**
Extinde Action enum:
```swift
public enum Action: Sendable {
  case avatarTapped
  case settingsTapped
  case storyTapped
  case insightSavedTapped
  case insightPaginationTapped(Int)
  case bondsAddTapped
  case delegate(Delegate)
}
public enum Delegate: Equatable, Sendable {
  case showAvatar, showSettings, showStory, showInsight, showAddBond
}
```
Reducer raman .none cu delegate forwarding pentru actiunile principale.

### Create — Layout/

**`Packages/Features/Home/Me/Layout/MeHeaderView.swift`** (~140 linii)
- Public View care primeste `StoreOf<MeFeature>` 
- Internal: HStack(top-right) cu doua `MeHeaderRoundButton`, VStack(bottom-left) cu eyebrow + title
- Background: ZStack cu LinearGradient + RadialGradient overlay
- Frame: height calculata via GeometryReader sau hardcoded (~310pt safe area top + 250pt)

**`Packages/Features/Home/Me/Layout/MeBodySheet.swift`** (~120 linii)
- Public View care primeste `StoreOf<MeFeature>`
- ScrollView vertical cu LazyVStack:
  - `StoryHeroCard` cu binding la state.story
  - `MeSectionHeader(title: "Insightul zilei")` + `DailyInsightCard`
  - `MeSectionHeader(title: "Legaturile tale")` + `BondsCard`
- Background `Color(.background)` cu `.clipShape(.rect(cornerRadii: .init(topLeading: 32, topTrailing: 32)))`
- Shadow inversa sus

### Create — Cards/

**`Packages/Features/Home/Me/Cards/StoryHeroCard.swift`** (~110 linii)
**`Packages/Features/Home/Me/Cards/DailyInsightCard.swift`** (~150 linii) — include AttributedString builder pt italic pe ultimul cuvant
**`Packages/Features/Home/Me/Cards/BondsCard.swift`** (~120 linii)

### Create — Components/

**`Packages/Features/Home/Me/Components/MeHeaderRoundButton.swift`** (~60 linii)
Enum variant (.avatar(String) / .icon(systemName)), padding 0, frame 42×42, clipShape Circle, dual shadow.

**`Packages/Features/Home/Me/Components/MeSectionHeader.swift`** (~30 linii)
HStack cu Text(title) Raleway Bold 18pt color: .text, padding 22pt horizontal 8/10pt vertical.

**`Packages/Features/Home/Me/Components/StoryIllustration.swift`** (~80 linii)
Custom Shape sau ZStack cu Paths pentru doua siluete abstracte (din SVG-ul `M28 38 c-4 -4 -4 -12 2 -16 ...`). Stroke cream (#FDFCF7) lineWidth 1.4.

**`Packages/Features/Home/Me/Components/CrescentIcon.swift`** (~40 linii)
Custom Path: `path.move(to: ...)` cu cubic curves pentru crescent shape (din SVG-ul `M22 5a12 12 0 1 0 5 12.5A9 9 0 0 1 22 5z`).

**`Packages/Features/Home/Me/Components/VennCirclesWatermark.swift`** (~40 linii)
ZStack cu doua `Circle().stroke(.accentWarm, lineWidth: 2.8)`, frame 178×116, primul offset.x = -25, secondul offset.x = +25.

**`Packages/Features/Home/Me/Components/InsightDotsPagination.swift`** (~40 linii)
HStack cu 3 elements: indexul activ → capsule 16×5pt `.accentWarm`, restul → circle 5pt `.text.opacity(0.18)`.

**`Packages/Features/Home/Me/Components/EllipsisMenuButton.swift`** (~30 linii)
Circle 26pt ivory bg cu Text("···") cocoa cardText color.

### Create — Models/

**`Packages/Features/Home/Me/Models/MeContent.swift`** (~80 linii)
```swift
struct MyStoryChapter: Equatable, Sendable {
  let id: UUID
  let chapterNumber: Int
  let category: String          // "Dragostea ta"
  let title: String
  let body: String
  // No illustration data yet — single hardcoded for mock
}

struct DailyInsightItem: Equatable, Sendable {
  let id: UUID
  let phaseLabel: String        // "Faza luteala · ziua 21"
  let text: String              // "Energia ta cere ritm interior. Asculta-l."
  let italicSuffix: String      // "Asculta-l."  (extracted for italic styling)
}

extension MyStoryChapter {
  static let mock = MyStoryChapter(
    id: UUID(), chapterNumber: 4, category: "Dragostea ta",
    title: "Mai usor de iubit cand te asculti pe tine.",
    body: "Trei luni de date spun ca ti-ai gasit propria voce."
  )
}

extension DailyInsightItem {
  static let mock = DailyInsightItem(
    id: UUID(), phaseLabel: "Faza luteala · ziua 21",
    text: "Energia ta cere ritm interior. Asculta-l.",
    italicSuffix: "Asculta-l."
  )
}
```

## Existing primitives to reuse

- `DesignColors` din `Packages/Core/DesignSystem/DesignColors.swift`:
  - `.text` (#5C4A3B), `.background` (#FDFCF7), `.textSecondary`, `.textCard`, `.accentWarm` (#C18F7D), `.accentWarmText` (#8E6052), `.divider` (#D8D3CB)
- `AppLayout` din `Packages/Core/DesignSystem/Layout.swift`:
  - `screenHorizontal` (14pt) – folosit pentru `.padding(.horizontal, AppLayout.screenHorizontal)`
  - `spacingS`, `spacingM`, `spacingL` (8/16/24)
  - `cornerRadiusXL` (30) – folosit pe carduri (am stabilit 22pt particular pt aceasta feature, mai mic decat XL)
- `AppTypography` din `Packages/Core/DesignSystem/Tokens/Typography.swift`:
  - `cardEyebrow` (Raleway SemiBold 11pt tracking 1.2)
  - `cardTitleSecondary` (Raleway Bold 22pt) – usable for greeting cu override font size
  - `bodyMedium` (Raleway Medium 13pt)
- Font helper Raleway existent (e.g. `.raleway("ExtraBold", size: 36, relativeTo: .largeTitle)`)
- SF Symbols pentru gear icon: `Image(systemName: "gearshape")`

Constanta noua de adaugat (in `MeView.swift` sau extension): peach gradient stops `Color(hex: 0xFFE2CE)`, `Color(hex: 0xFFCDB0)`, `Color(hex: 0xFFBA9A)`.

## Folder structure rezultata

```
Packages/Features/Home/Me/
├── MeView.swift              (modify)
├── MeFeature.swift           (modify)
├── Cards/
│   ├── StoryHeroCard.swift
│   ├── DailyInsightCard.swift
│   └── BondsCard.swift
├── Components/
│   ├── MeHeaderRoundButton.swift
│   ├── MeSectionHeader.swift
│   ├── StoryIllustration.swift
│   ├── CrescentIcon.swift
│   ├── VennCirclesWatermark.swift
│   ├── InsightDotsPagination.swift
│   └── EllipsisMenuButton.swift
├── Layout/
│   ├── MeHeaderView.swift
│   └── MeBodySheet.swift
└── Models/
    └── MeContent.swift
```

Respecta conventia "Cards/Components/Sheets/Screens/Layout/Models per feature". `Sheets/` si `Screens/` raman goale pentru viitor (Chapter Detail / Bond Detail / Add Person sheet vor veni in ciclul urmator).

## Verification

User-ul ruleaza build manual in Xcode (nu xcodebuild CLI). Dupa fiecare batch de fisiere create, eu las user-ul sa build & rule pe simulator. Verifica:

1. ME tab nu mai e blank – are header peach + body sheet ivory cu cele 3 carduri vizibile.
2. Greeting "Lorem ipsum dolor." apare stanga jos in header zone, Raleway ExtraBold 36pt.
3. Cele 2 butoane round (avatar M cu gradient cocoa, settings gear) sunt vertical stacked pe dreapta sus.
4. StoryHeroCard are zona cocoa dark stanga 120pt cu line-art cream (doua siluete) si text dreapta.
5. DailyInsightCard centrat cu CrescentIcon top, label "Faza luteala · ziua 21", text bold cu "Asculta-l." italic, pill outlined "Pastreaza-l", paginatie 3 dots sub card.
6. BondsCard cu watermark Venn cercuri cocoa-warm 30% opacity in colt dreapta-sus partial taiate de edge, pill filled cocoa "+ Adauga prima" stanga jos.
7. Body sheet are top-left + top-right radius 32pt, shadow inversa sus.
8. Scroll funcţioneaza – cardurile scrolleaza in spatele top zone-ului peach.

## Out of scope (urmatorul ciclu)

- Chapter Detail Screen (cand tap pe StoryHeroCard)
- Bond Detail Screen (cand exista bonds salvate)
- Add Person Sheet (cand tap "+ Adauga prima")
- Settings Sheet
- Avatar Profile/Settings Sheet
- Wire date reale din SwiftData (acum mock)
- Final copy pentru greeting (acum "Lorem ipsum dolor.")
- Animatie peach lens (acum static gradient)
- Multi-insight carousel (acum 1 insight + 3 dots stoice)
