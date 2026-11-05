# Suggest tab

The Suggest tab proposes perks and add-ons that support each other. It runs fully on the device: no internet
and no large model. A small model is trained offline from the bundled perk and add-on descriptions.

## 1. Big picture

```mermaid
flowchart LR
    subgraph Offline["Offline (on the Mac, re-run when the data changes)"]
        P[("perks.json<br/>addons.json")] --> T["tools/synergy/<br/>build_synergy.py"]
        T --> S[("Resources/<br/>synergy.json")]
    end
    subgraph App["On the device"]
        S --> R["BundledSynergyRepository"]
        R --> E["SynergyEngine"]
        E --> VM["SuggestViewModel"]
        VM --> V["SuggestView"]
    end
```

## 2. What the trainer learns

```mermaid
flowchart TD
    D["Item description<br/>(add-ons: lore line dropped)"] --> C["Split into condition and effect clauses<br/>'While X, you gain Y'"]
    C --> PR["Produces<br/>statuses it gives out<br/>(Exposed, Hindered, Haste, ...)"]
    C --> CO["Consumes<br/>statuses it needs or pays off on"]
    D --> TH["Themes<br/>(Generator pressure, Healing, Chase, ...)<br/>add-ons also: Cooldown, Range, Duration, ..."]
    D --> TF["TF-IDF"] --> SVD["Truncated SVD<br/>16-dim embedding"]
    PR --> OUT[("synergy.json")]
    CO --> OUT
    TH --> OUT
    SVD --> OUT
```

## 3. How two items are scored

Synergy is complementarity, not similarity: one item gives a status the other one uses.

```mermaid
flowchart TD
    A["Item A"] --> L
    B["Item B"] --> L
    L{"Producer/consumer link?<br/>A produces what B consumes<br/>(or the reverse)"}
    L -->|"+3.0 per link, max 2"| SUM
    A --> TT
    B --> TT
    TT{"Shared themes?"}
    TT -->|"+1.0 per theme, max 2"| SUM
    A --> CS
    B --> CS
    CS{"Embedding cosine"}
    CS -->|"+0.8 x min(cos, 0.6)"| SUM
    CS -->|"cos > 0.9: near duplicate<br/>-2.5"| SUM
    SUM(["Pair score + plain-language reasons"])
```

## 4. How a suggestion is built

```mermaid
flowchart TD
    START{"User picked a seed?"}
    START -->|No| RND["Random start<br/>perks: random role, prefers tagged items<br/>add-ons: random power or item with 2+ add-ons"]
    START -->|Yes| SEED["Seed = picked perk or add-on"]
    RND --> POOL
    SEED --> POOL["Candidate pool<br/>perks: same role<br/>add-ons: same parent power or item"]
    POOL --> RANK["Score every candidate<br/>against the items chosen so far"]
    RANK --> FAIR["Keep top 4 within 1.0 of the best"]
    FAIR --> PICK["Pick one at random"]
    PICK --> DONE{"Set full?<br/>perks: 4, add-ons: 2"}
    DONE -->|No| RANK
    DONE -->|Yes| OUT(["Suggestion: items + top 3 reasons"])
```

## 5. User flow

```mermaid
sequenceDiagram
    actor U as User
    participant V as SuggestView
    participant VM as SuggestViewModel
    participant E as SynergyEngine
    V->>VM: init (load synergy.json, perks, add-ons)
    VM->>E: randomPerkSet(count 4)
    E-->>VM: suggestion
    VM-->>V: picks + reasons
    U->>V: tap Shuffle
    V->>VM: shuffle()
    VM->>E: new draw
    U->>V: switch to Add-ons
    V->>VM: modeChanged() (clears seed)
    VM->>E: randomAddonPair()
    U->>V: type in the search bar
    V->>VM: updateSearch() (CatalogSearch, filtered by mode)
    U->>V: tap a result
    V->>VM: select(entry)
    VM->>E: completePerk or completeAddon(seed)
    E-->>VM: seed + best partners
    VM-->>V: picks + reasons
```

## Files

| File | Role |
|---|---|
| `tools/synergy/build_synergy.py` | offline trainer (pure Python, no packages) |
| `DBD Perks/Resources/synergy.json` | trained data |
| `DBD Perks/Utils/SynergyData.swift` | data model and bundle loader |
| `DBD Perks/Utils/SynergyEngine.swift` | scoring and suggestion building |
| `DBD Perks/Module/Suggest/` | view and view model |
| `DBD PerksTests/SynergyEngineTests.swift` | engine tests |

## Limits

- There are no "good combo" labels in the data, so quality is a heuristic, not a measured accuracy.
- Only part of the items have a producer/consumer link; the rest rely on themes and the embedding.
