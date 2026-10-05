# Battleplan — Build Guide

How to build Battleplan, a World of Warcraft: Forever addon, the same way Gearwright and
GearwrightProbe are built, with one extra non-negotiable: **the UI must feel fluid and
the addon must never cause a hitch in game.**

> Addon: **Battleplan** (`/bplan`). Dev companion: **BattleplanProbe** (`/bpp`).

---

## 0. Dev workflow

- **Ask questions only when absolutely necessary; work autonomously.** If the answer is in
  the repo, the docs or a probe capture, or a reasonable default exists and a wrong guess
  is cheap to fix, decide and keep going. Write the decision in the commit message and the
  doc it affects. Stop and ask only for things that are costly or hard to undo.
- **Do things properly: this is production grade, not a hack project.** Every change has
  tests, passes lint and the perf budgets, keeps the architecture rules, updates the docs,
  and is committed and pushed with CI green. No temporary shortcuts.
- **[AGENTS.md](../AGENTS.md) holds the concrete development guidelines**: commands,
  repository map, Lua and performance rules, testing, data provenance, commits, and the
  definition of done. `CLAUDE.md` points to it.
- **Skills in [.claude/skills/](../.claude/skills/) cover the recurring jobs** step by step:

  | Skill | When |
  |---|---|
  | `verify-change` | Before every commit |
  | `import-probe-capture` | A `/bpp export` or `/gwp export` arrives |
  | `add-class` | A new class or role guide |
  | `add-game-api` | Reading something new from the client |
  | `update-data` | Changing builds, rotations, weights, consumables, enchants |

- **The architecture rules are enforced, not just written down**: `tests/test_rules.py`
  fails CI on game reads outside `Core/API.lua`, WoW calls in `Engine/`, data files
  without `_status`, files missing from a `.toc`, and stray `OnUpdate` scripts.

---

## 1. What this addon does

An **out-of-combat build planner**. It tells the player how to set up their character
and how to play it. It does not try to tell them what to press mid-fight.

Addon code can't read the health of the mob the player is fighting (Forever hides it
as a secret value), so a live "cast this next" display can't be made reliable. That
display is cut. Everything the addon does is advice the player reads before a pull,
between pulls, or while leveling.

### Pillars

1. **Talent builds by situation.** The theorycrafted best build for the player's spec,
   with separate builds for leveling, solo, dungeon, and raid (PvP later).
2. **Rotation guide by level and known spells.** The best rotation the player can
   actually perform right now, given their level and the spells and ranks they've
   learned. It updates when they level up or learn something.
3. **Next-best gear and consumables.** The next upgrade to chase for each slot, plus
   the best enchants, elixirs/flasks, weapon stones/oils, and food buffs for the spec
   and situation.
4. **Role guides.** For healers, a healing approach that keeps the party alive without
   running the healer out of mana. For tanks, a threat and survival guide.

### Scope

- **v1:** one DPS class first (like Gearwright starting with Rogue), then one healer
  spec and one tank spec so all three role guides get built and tested early.
- **Out of scope for v1:** any in-combat display or prompt, live enemy tracking, combat
  logging and parsing, PvP builds, the account-wide Legacy system.

### 1.1 Talent builds

- Each spec has one build per situation: `leveling`, `solo`, `dungeon`, `raid`.
- The leveling build is a **point-by-point order** (level 10 → 60), so the addon can
  say "your next point goes here." The others are a finished 51-point build plus the
  reason for each key choice.
- Show the difference between the player's current talents and the recommended build.
- The window lets the player pick the situation; the default is `leveling` below max
  level and `dungeon` at max level.

### 1.2 Rotation guide

- Stored as a **priority list** per spec and situation, where each entry names a spell,
  the minimum level it's available, and a condition written in plain words
  ("keep Slice and Dice up", "use at 5 combo points").
- The Engine filters the list to spells the player **knows right now** and the best
  rank they have, so a level-22 player sees a level-22 rotation.
- Includes an "opener" and a short "what changed" note when a new spell or rank is
  learned (e.g. on level-up: "You can now train X; it goes 2nd in your priority").
- It's a reference card in the window, never an on-screen prompt.

### 1.3 Gear and consumables

- **Next upgrade per slot:** the best realistic item the player can get at their level,
  where it drops or comes from, and how much better it is (using stat weights, like
  Gearwright's scoring).
- **Enchants:** best enchant per slot and which equipped slots are missing one.
- **Consumables by situation:** elixirs/flasks, weapon stones/oils, food buffs, and
  potions, each tied to the spec's stat weights. Raid gets the full list; leveling gets
  the cheap, practical version.
- **Buff check (out of combat):** read the player's active auras and flag missing
  consumable buffs ("no food buff", "weapon not sharpened") before a pull. Confirm with
  the probe that aura data is readable out of combat.
- Professions and recipes were reworked for Forever, so every item, enchant, and
  consumable ID starts as `provisional` until confirmed in game.

### 1.4 Healer guidance

Built for healer specs (Priest, Paladin, Druid, Shaman as they're added).

- **Spell choice by situation:** which heal to use for a light top-up, sustained tank
  damage, a sudden spike, and group-wide damage.
- **Mana efficiency table:** healing per mana for every heal and rank the player knows,
  so they can see which spells are cheap and which are emergency-only. If Forever keeps
  spell ranks, the guide includes when to use a lower rank to save mana (the probe
  confirms whether ranks exist).
- **Mana plan:** how to pace mana over a pull. When to stop casting to regenerate,
  which cooldowns and regen tools to use (mana potions, class abilities, spirit or
  mana-per-5 gear), and which consumables support a long fight.
- **Healer stat weights** drive the gear and consumable pillar too (healing power vs
  regen vs intellect), with separate weights for dungeon and raid.
- Like the rotation, this is a reference card, not a live display.

### 1.5 Tanking guidance (tank specs only)

Built for tank specs (Warrior, Druid, Paladin as they're added). Same rule as the
others: a reference card read between pulls, not a live display. Threat data is likely
hidden as secret values in combat, so the addon doesn't try to track it live.

- **Threat priority:** the rotation for single-target threat and for holding several
  mobs, filtered to known spells and ranks like the DPS rotation.
- **Pull plan:** how to open on a pack (marking, line-of-sight pulls, which mob to
  build on first) written as short notes per situation.
- **Mitigation stat weights:** armor, stamina, defense, dodge/parry/block, and any new
  Forever stats, with separate weights for dungeon and raid. If Forever keeps a defense
  target that makes bosses unable to crit the tank, the Gear tab shows the player's
  progress toward it (the stat lab in 1.7 confirms whether it exists and what the
  number is).
- **Defensive cooldowns:** what each one is for and when to save it.
- **Tank consumables:** health and armor elixirs, stamina food, and health potions,
  weighted by the tank's stat weights.
- **Threat vs survival setup:** a "safe" build and a "threat" build per situation, so a
  geared tank in an easy dungeon can lean into threat and a fresh tank can lean into
  survival.

### 1.6 Where the theorycrafting happens

The math runs **outside the game**, in `tools/`:

- `tools/theorycraft/` holds a simple spreadsheet-style model per spec (damage per
  second, or healing per mana for healers) that compares talent builds, rotations, and
  stat weights.
- Its output is written as Lua tables into `Data/<CLASS>/`.
- The addon only **reads** those tables and filters them for the player's level, known
  spells, and gear. That keeps the in-game cost tiny and the logic testable.
- Every result keeps the `provisional` status until it's checked against beta or live
  play.

### 1.7 Stat lab: pulling every stat from the game

The theorycraft models are only as good as their inputs. Forever changed stats and
itemization (new stats such as expertise, haste, and spell damage, and Blizzard said
it wants to "un-solve" the game), so Classic formulas can't be trusted. Before
building models, measure how each stat actually works.

**What to capture (all out of combat, via `BattleplanProbe`):**

| Group | What to read |
|---|---|
| Primary | Strength, Agility, Stamina, Intellect, Spirit (base and bonus) |
| Offense | Attack power, ranged attack power, crit chance (melee/ranged/spell), hit, expertise, haste, spell damage and healing power by school |
| Defense | Armor, defense, dodge, parry, block chance and block value, resistances |
| Resources | Max health and mana, mana regen (casting and not casting), energy/rage behavior |
| Weapon | Main-hand/off-hand damage range and speed |
| Ratings | Every combat rating the client exposes, and its converted percentage |
| Items | Full stat list per equipped item, plus any "Equip:" text lines |

Every reading goes through `Core/API.lua`, and each capture is tagged with class, race,
level, spec, and equipped gear.

**How to work out conversions:** the probe's `/bpp stats` takes a snapshot, and
`/bpp stats diff` compares it to the last one. Change one thing at a time and diff:

1. Snapshot naked (no gear, no buffs).
2. Equip one item with a single known stat (e.g. +10 Agility), snapshot, diff. That
   gives the conversion (Agility → attack power, crit, armor, dodge) for that class and
   level.
3. Repeat for each primary and secondary stat, then for one enchant, one elixir, one
   weapon stone, and one food buff.
4. Repeat at several levels (e.g. 10, 20, 30), because conversion rates in WoW usually
   change with level. The beta stops at level 30, so level 60 values will need
   rechecking at launch.
5. Repeat across classes where it matters (Agility gives different crit per class).

**Output:** `tools/stat_lab.py` turns the diffs into a conversion table
(`data/stats/conversions.json`: stat, class, level, per-point effect) and fits the
level scaling where there are enough points. The theorycraft models read that table
instead of hard-coded Classic numbers.

**Priority for the beta window (ends Oct 22):** primary stat conversions for the v1
class and the first healer and tank classes, then the new Forever stats, then
consumable buff values.

---

## 2. Ground rules (same as Gearwright)

1. **Only `Core/API.lua` touches game data APIs.** Forever's API is still moving and
   restricted (Midnight-style "secret values"). When the probe shows something works
   differently, you fix one file.
2. **Engine has no WoW calls.** It takes plain tables and returns plain tables, so it runs
   in the offline smoke test.
3. **Data is data.** Weights, lists, and lookups live as Lua tables in `Data/`. Adding a
   class means adding a folder, not touching the engine.
4. **Every data file carries a status:** `_status = "provisional" | "todo" | "verified"`.
   The UI shows a warning while anything is provisional.
5. **Each file gets the shared namespace** with `local _, ns = ...`. No globals except the
   SavedVariables table and the slash command.
6. **Build against the modern (Mainline) API, not Classic 1.15.** Forever's interface
   number is Classic-style (16001), but its APIs are Mainline's: `C_Item`, `C_Spell`,
   `C_Traits`, `TooltipDataProcessor`. Classic-era globals like `GetItemStats` and
   `GetTalentInfo` are gone.

---

## 3. Repo layout

```
Battleplan/            The addon players install
  Battleplan.toc
  Core/                Init, Util, Events, Scheduler, API wrapper, Perf, Commands
  Data/
    Stats.lua          Stat names and units
    Consumables.lua    Elixirs, flasks, stones/oils, food, potions (shared)
    <CLASS>/           Specs, Weights, Talents, Rotations, Gear, Enchants
                       (+ Healing for healers, Tanking for tanks)
  Engine/              Pure logic, no WoW calls:
                       Spec, Talents, Rotation, Gear, Consumables, Healing, Tanking
  UI/                  Main window with tabs (Talents / Rotation / Gear / Consumables
                       / Healing or Tanking), tooltip line, animations
BattleplanProbe/       Dev-only addon: dumps what the Forever client exposes, stat lab
tools/                 probe_to_json.py, stat_lab.py, theorycraft/ models
data/stats/            conversions.json produced by the stat lab
tests/                 smoke_test.py + perf_test.py against a mocked WoW API
docs/                  ARCHITECTURE.md, BETA-CHECKLIST.md, PERFORMANCE.md
data/probe/            Committed probe captures (raw research data)
```

### TOC

```
## Interface: 16001
## Title: Battleplan
## Notes: One line on what it does.
## Version: 0.1.0
## SavedVariables: BattleplanDB

Core\Init.lua
Core\Util.lua
Core\Events.lua
Core\Scheduler.lua
Core\Perf.lua
Core\API.lua
Data\Stats.lua
Data\Consumables.lua
Data\ROGUE\Specs.lua
Data\ROGUE\Weights.lua
Data\ROGUE\Talents.lua
Data\ROGUE\Rotations.lua
Data\ROGUE\Gear.lua
Data\ROGUE\Enchants.lua
Engine\Spec.lua
Engine\Talents.lua
Engine\Rotation.lua
Engine\Gear.lua
Engine\Consumables.lua
Engine\Healing.lua
Engine\Tanking.lua
UI\Animations.lua
UI\Tooltip.lua
UI\MainWindow.lua
UI\Tabs.lua
Core\Commands.lua
```

### Data shapes

```lua
-- Data/ROGUE/Rotations.lua
local _, ns = ...
ns.Data.ROGUE.Rotations = {
  _status = "provisional",
  combat = {
    dungeon = {
      opener = { "Sinister Strike", "Slice and Dice" },
      priority = {
        { spell = "Slice and Dice",  minLevel = 10, note = "keep it up at all times" },
        { spell = "Eviscerate",      minLevel = 1,  note = "at 5 combo points" },
        { spell = "Sinister Strike", minLevel = 1,  note = "builder" },
      },
    },
  },
}

-- Data/Consumables.lua (shared)
ns.Data.Consumables = {
  _status = "provisional",
  { itemID = 0, kind = "elixir", stat = "AGILITY", amount = 0, minLevel = 0,
    situations = { "dungeon", "raid" } },
  -- kinds: elixir, flask, weapon_stone, weapon_oil, food, potion
}
```

Use spell IDs, not names, once the probe confirms them; names above are placeholders.

### Refresh triggers (all coalesced, all out of combat)

| Event | Refreshes |
|---|---|
| `PLAYER_LEVEL_UP` | Rotation, talent next-point, gear and consumable level filters |
| `SPELLS_CHANGED` / learned spell | Rotation, healing table |
| Talent change events (per probe) | Talent diff, spec detection, weights |
| `PLAYER_EQUIPMENT_CHANGED` | Gear upgrades, missing enchants |
| `UNIT_AURA` (player, out of combat only) | Buff check |

Interface 16001 is confirmed on the beta (client 1.60.1, build 70205). Check it again
after launch with `/dump select(4, GetBuildInfo())` and update both `.toc` files if it moves.

Load order: **Core → Data → Engine → UI → Commands.**

---

## 4. Performance budget (the "no hitching" contract)

A hitch is one frame that takes noticeably longer than the ones around it. At 60 fps a
frame is ~16.7 ms, and the game itself uses most of it. The addon gets a small slice.

| Situation | Budget | Rule |
|---|---|---|
| Any single event handler | **< 0.5 ms** typical, **never > 2 ms** | Heavy work goes to the scheduler |
| Tooltip hook | **< 0.2 ms** | Cached result, no scoring on hover after first time |
| Window open | **< 2 ms** on frame 1 | Build lazily, fill rows over following frames |
| In combat | **~0 ms, zero allocations** | Addon is dormant: every handler returns immediately; refresh once on `PLAYER_REGEN_ENABLED` |
| Idle (window closed) | **0 ms** | No OnUpdate scripts running, no tickers |
| Login / `/reload` | **< 20 ms** total on first frame | Defer non-critical setup with `C_Timer.After(0, ...)` |

These are the acceptance criteria. Section 10 says how to measure them.

---

## 5. Core modules (copy these patterns)

### 5.1 Init

```lua
-- Core/Init.lua
local ADDON, ns = ...
ns.name = ADDON
ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version")

local DEFAULTS = { window = { shown = false }, tooltip = true, debugPerf = false }

function ns:InitDB()
  BattleplanDB = BattleplanDB or {}
  for k, v in pairs(DEFAULTS) do
    if BattleplanDB[k] == nil then BattleplanDB[k] = v end
  end
  ns.db = BattleplanDB
end
```

Keep SavedVariables small. Never save computed data that can be rebuilt; large saved
tables slow down every login and logout. (SavedVariables do persist between
sessions on the Forever beta: confirmed by GearwrightProbe on 2026-10-03.)

### 5.2 Event bus with coalescing

One frame owns all events. Handlers are plain functions.

```lua
-- Core/Events.lua
local _, ns = ...
local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
local handlers = {}

function Events:On(event, fn)
  local list = handlers[event]
  if not list then
    list = {}
    handlers[event] = list
    frame:RegisterEvent(event)
  end
  list[#list + 1] = fn
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  for i = 1, #list do list[i](event, ...) end
end)
```

**Coalesce bursty events.** `BAG_UPDATE`, `UNIT_INVENTORY_CHANGED`,
`PLAYER_EQUIPMENT_CHANGED`, and talent events can fire many times in one frame.
Never recompute per event. Mark dirty and recompute once:

```lua
local pending = {}

-- Runs fn once, `delay` seconds after the first call in a burst.
function ns.Coalesce(key, delay, fn)
  if pending[key] then return end
  pending[key] = true
  C_Timer.After(delay or 0, function()
    pending[key] = nil
    fn()
  end)
end

-- Usage
Events:On("PLAYER_EQUIPMENT_CHANGED", function()
  ns.Coalesce("gear", 0.1, ns.RefreshGear)
end)
```

### 5.3 Scheduler: spread heavy work across frames

Anything that loops over many items (scanning bags, scoring a gear list, building a
large data index) runs as a coroutine with a per-frame time budget.

```lua
-- Core/Scheduler.lua
local _, ns = ...
local Jobs = {}
ns.Jobs = Jobs

local BUDGET_MS = 2
local queue, head, tail = {}, 1, 0
local runner = CreateFrame("Frame")
runner:Hide() -- a hidden frame's OnUpdate does not run, so idle cost is zero

function Jobs:Run(fn)
  tail = tail + 1
  queue[tail] = coroutine.create(fn)
  runner:Show()
end

runner:SetScript("OnUpdate", function(self)
  if InCombatLockdown() then return end -- pause during combat
  local start = debugprofilestop()
  while head <= tail do
    local co = queue[head]
    local ok, err = coroutine.resume(co)
    if not ok then geterrorhandler()(err) end
    if coroutine.status(co) == "dead" then
      queue[head] = nil
      head = head + 1
    end
    if debugprofilestop() - start > BUDGET_MS then return end
  end
  head, tail = 1, 0
  self:Hide()
end)
```

Inside a job, yield every N units of work:

```lua
ns.Jobs:Run(function()
  for i = 1, #items do
    score(items[i])
    if i % 25 == 0 then coroutine.yield() end
  end
  ns.UI:Refresh()
end)
```

### 5.4 Combat safety

```lua
local afterCombat = {}

function ns.OutOfCombat(fn)
  if not InCombatLockdown() then return fn() end
  afterCombat[#afterCombat + 1] = fn
end

ns.Events:On("PLAYER_REGEN_ENABLED", function()
  for i = 1, #afterCombat do
    local fn = afterCombat[i]
    afterCombat[i] = nil
    fn()
  end
end)
```

Rules:
- **The addon is dormant in combat.** It has no combat display, so every handler starts
  with `if InCombatLockdown() then ns.dirty = true return end`. One coalesced refresh
  runs on `PLAYER_REGEN_ENABLED` if anything was marked dirty.
- `UNIT_AURA` fires constantly. Only handle it for `"player"`, only out of combat, and
  only through `ns.Coalesce`.
- Never create, move, resize, or show/hide frames that touch protected UI in combat.
  Route those through `ns.OutOfCombat`.
- Don't rescan or rescore in combat. Mark dirty; refresh on `PLAYER_REGEN_ENABLED`.
- Combat data may come back as **secret values**. All reads go through `API.lua`, which
  checks for them (e.g. with `issecretvalue` if the client provides it) and returns
  `nil` instead of letting a secret leak into Engine math.

### 5.5 API wrapper and caching

`Core/API.lua` is the only file that calls game data APIs. It also owns the caches.

- **Item data is async.** `C_Item.GetItemInfo` returns nil for uncached items. Use
  `Item:CreateFromItemLink(link):ContinueOnItemLoad(fn)` instead of polling or retrying.
- **Cache derived results by itemLink.** Wipe the cache when the thing it depends on
  changes (gear, spec, talents). Cap it (e.g. wipe at 500 entries) so it can't grow
  forever.
- **Feature-detect, don't assume.** `if C_Traits then ... elseif GetTalentInfo then ...`
  The probe tells you which branch is real; the wrapper keeps the rest of the code
  ignorant of it.

---

## 6. UI fluidity rules

### 6.1 Build lazily, open instantly
- Don't create the main window at login. Create it the first time it's opened.
- On open: show the frame and play the fade-in immediately (frame 1), then fill content
  through the scheduler. The player sees motion right away instead of a stall.
- Reuse frames. Hide on close; never destroy and recreate.

### 6.2 Animate with AnimationGroups, not OnUpdate
AnimationGroups run in the client's C code and stay smooth even when Lua is busy.

```lua
-- UI/Animations.lua
local _, ns = ...

function ns.AddFade(frame, duration)
  local ag = frame:CreateAnimationGroup()
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(0)
  a:SetToAlpha(1)
  a:SetDuration(duration or 0.15)
  a:SetSmoothing("OUT")
  ag:SetToFinalAlpha(true)
  frame.fadeIn = ag

  local out = frame:CreateAnimationGroup()
  local b = out:CreateAnimation("Alpha")
  b:SetFromAlpha(1)
  b:SetToAlpha(0)
  b:SetDuration(duration or 0.12)
  b:SetSmoothing("IN")
  out:SetToFinalAlpha(true)
  out:SetScript("OnFinished", function() frame:Hide() end)
  frame.fadeOut = out
end

function ns.ShowSmooth(frame)
  frame.fadeOut:Stop()
  frame:Show()
  frame.fadeIn:Play()
end

function ns.HideSmooth(frame)
  frame.fadeIn:Stop()
  frame.fadeOut:Play()
end
```

- Keep UI animations short: **0.10–0.20 s**. Long fades feel laggy, not smooth.
- Use `Translation` / `Scale` animations for slide or pop effects the same way.
- If you truly need a value to glide (a bar filling, a number counting up), use one
  OnUpdate that lerps by `elapsed`, and **hide/unset it the moment it reaches the
  target**. Never leave an OnUpdate running on a visible-but-idle frame.

### 6.3 Lists: recycle rows
Never create one frame per row for a long list. Create only as many row frames as fit
on screen and rebind them to new data as the list scrolls. Battleplan does this in
`UI/List.lua` (no XML templates, so it doesn't depend on ScrollBox internals that may
differ on Forever):

```lua
function List:Rebind()
  for i, row in ipairs(self.rows) do
    local d = self.data[self.offset + i]
    if d then bind(row, d) end       -- set text only; no layout rebuild
    row:SetShown(d ~= nil)
  end
end
```

`tests/perf_test.py` checks that scrolling allocates nothing.

For small, fixed sets of widgets that come and go (icons, badges), use
`CreateFramePool` / `CreateObjectPool` instead of creating new frames.

### 6.4 Avoid layout thrash
- Set anchors once at creation. Don't `ClearAllPoints` / `SetPoint` on every refresh.
- Use `SetShown(bool)` instead of branching `Show()` / `Hide()`.
- Only update a FontString if its text actually changed (`if fs.last ~= text then ...`).
  `SetText` and `GetStringWidth` trigger layout work.
- Don't measure text widths in a loop.

### 6.5 Tooltip line
Battleplan doesn't add item tooltip lines: Gearwright already does, and two addons
writing upgrade lines on the same tooltip would disagree. If a tooltip line is ever
added, use the modern tooltip data processor and keep it to a cache lookup:

```lua
local cache, count = {}, 0

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
  if not ns.db.tooltip then return end
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  local _, link = TooltipUtil.GetDisplayedItem(tooltip)
  if not link then return end

  local line = cache[link]
  if line == nil then
    line = ns.Engine:TooltipLine(link) or false
    if count > 500 then wipe(cache); count = 0 end
    cache[link] = line
    count = count + 1
  end
  if line then tooltip:AddLine(line) end
end)

function ns.ClearTooltipCache() wipe(cache); count = 0 end
```

Call `ns.ClearTooltipCache()` from the coalesced gear/spec refresh.

---

## 7. Lua habits that prevent garbage-collection hitches

Most "random" addon hitches are the garbage collector cleaning up after code that
allocated too much. In hot paths (events, tooltip, OnUpdate, anything in combat):

- **No new tables per call.** Keep a module-level table and `wipe()` it.
- **No closures per call.** Define functions once at file scope; don't write
  `C_Timer.After(0, function() ... end)` inside something that fires often.
- **No string building in loops.** Use `table.concat` on a reused buffer, or
  `string.format` once at the end.
- **Localize globals used in hot loops:** `local pairs, ipairs, wipe = pairs, ipairs, wipe`.
- **Never call `collectgarbage()`** to "clean up". Forcing a full collection is itself a
  hitch.
- Precompute lookup tables at load (or lazily on first use) instead of searching lists
  every call.

---

## 8. The companion probe addon (`BattleplanProbe`)

Same idea as GearwrightProbe: a dev-only addon you don't ship, which records what the
Forever client actually exposes for this addon's needs.

- `/bpp all` dumps environment (interface number, client build), which APIs exist,
  and the raw data this addon will read.
- `/bpp export` opens a copyable JSON box (Ctrl+A, Ctrl+C) to paste into
  `data/probe/`.
- Records which values come back as secret values in and out of combat.
- Records what the planner needs:
  - Talent API (`C_Traits` vs classic `GetTalentInfo`) and talent IDs per tree
  - Known spells, their IDs, **whether spell ranks exist**, and mana/energy costs per rank
  - Trainer lists (spell + level), recorded when the trainer window opens
  - Player auras out of combat: are food, elixir, flask, and weapon-stone/oil buffs
    readable, and what are their spell IDs
  - Consumable and enchant item IDs from professions windows and vendors
  - Healer data: healing spell base values and costs, so the healing-per-mana table can
    be checked against the theorycraft model
  - Tank data: armor, defense, avoidance and block numbers, and whether threat APIs
    return anything usable out of combat
- **Stat lab** (section 1.7): `/bpp stats` snapshots every stat, `/bpp stats diff`
  compares against the last snapshot, and both are included in `/bpp export`.
- Add a **perf mode**: `/bpp perf` logs frame times for 30 seconds (see 10.2) so you can
  compare a session with the main addon enabled vs disabled.

Commit every capture to `data/probe/YYYY-MM-DD-<topic>.json` and run
`tools/probe_to_json.py` on it.

---

## 9. Offline tests

Same setup as Gearwright: `pip install lupa`, then run against a mocked WoW API.

- **`tests/smoke_test.py`** loads Core, Data, and Engine in TOC order with a mock
  `CreateFrame`, `C_Timer`, `C_Item`, etc., and checks Engine outputs for known inputs.
- **`tests/perf_test.py`** (new for this addon):
  - Runs the Engine's hot functions 10,000 times and fails if average time exceeds the
    budget scaled for the test machine.
  - Measures `collectgarbage("count")` before and after a hot path run in a loop and
    fails if memory grows (target: no growth for cached tooltip lookups and steady-state
    event handling).

Note: lupa runs Lua 5.4; WoW runs a modified Lua 5.1. Avoid 5.2+ features (`goto`,
integer division `//`, `utf8`, bitwise operators) so code that passes tests also loads
in game.

---

## 10. Measuring hitching in game

### 10.1 Built-in instrumentation (`Core/Perf.lua`)
Wrap every event handler, the tooltip hook, and each scheduler slice with timing when
`ns.db.debugPerf` is on:

```lua
local _, ns = ...
local stats = {}

function ns.Timed(label, fn)
  return function(...)
    if not ns.db or not ns.db.debugPerf then return fn(...) end
    local t = debugprofilestop()
    fn(...)
    local ms = debugprofilestop() - t
    local s = stats[label]
    if not s then s = { n = 0, total = 0, max = 0 }; stats[label] = s end
    s.n, s.total = s.n + 1, s.total + ms
    if ms > s.max then s.max = ms end
  end
end

function ns.PerfReport()
  for label, s in pairs(stats) do
    print(("%s  n=%d  avg=%.3fms  max=%.3fms"):format(label, s.n, s.total / s.n, s.max))
  end
end
```

Register handlers as `Events:On("X", ns.Timed("X", handler))`. Then `/bplan perf` prints
the report. Anything whose **max** breaks the section 4 budget is a bug.

### 10.2 Client-side checks
- If the Forever client has the addon CPU profiler (`C_AddOnProfiler`, present in
  modern Retail), read the addon's recent/peak time from it. Confirm with the probe.
- `/etrace` shows which events fire and how often; use it to find bursts worth
  coalescing.
- Compare frame times with the addon enabled vs disabled in the same spot (a busy city,
  then a dungeon pull). Spikes that only appear with the addon on are yours.

---

## 11. Build order

1. **Probe and stat lab first.** Write `BattleplanProbe` with the stat snapshot/diff
   commands, run the section 1.7 experiments on the beta before Oct 22, answer the API
   questions in `docs/BETA-FINDINGS.md`, and build `tools/stat_lab.py`.
2. **Core:** Init, Events, Scheduler, Perf, API wrapper (with feature detection).
3. **Theorycraft models** in `tools/theorycraft/` for the first DPS spec; generate
   talent builds, rotations, and stat weights into `Data/`, all `provisional`.
4. **Engine:** Spec → Talents (diff + next point) → Rotation (filter by level/known
   spells) → Gear (next upgrade, missing enchants) → Consumables (by situation, buff
   check). Smoke test + perf test for each.
5. **UI:** main window (lazy, animated, recycled rows) with Talents, Rotation, Gear, and
   Consumables tabs, then the tooltip line.
6. **First healer spec:** healing model in `tools/theorycraft/`, `Engine/Healing.lua`,
   and the Healing tab (spell choice by situation, healing-per-mana table, mana plan).
7. **First tank spec:** mitigation model in `tools/theorycraft/`,
   `Engine/Tanking.lua`, and the Tanking tab (threat priority, pull plan, defensive
   cooldowns, mitigation weights).
8. **Commands:** `/bplan`, `/bplan situation <leveling|solo|dungeon|raid>`, `/bplan perf`,
   `/bplan reset`.
9. **In-game perf pass** (section 10) in a city, while leveling, and through a dungeon
   pull to confirm the addon does nothing in combat.
10. Recheck stat conversions at level 60 after launch, then replace provisional data with verified data as the beta and launch provide it.

---

## 12. Definition of done (every change)

- [ ] `python tests/smoke_test.py` passes
- [ ] `python tests/perf_test.py` passes (time budget + no memory growth)
- [ ] `python tests/test_tools.py` and `python tests/test_rules.py` pass, and `luacheck .` is clean
- [ ] No game data API calls outside `Core/API.lua`
- [ ] No OnUpdate script left running while idle
- [ ] No frame work during combat that isn't deferred through `ns.OutOfCombat`
- [ ] Bursty events are coalesced
- [ ] `/bplan perf` shows every handler under budget after 10 minutes of normal play
- [ ] Window opens on the first frame with a fade, contents fill without a stall
- [ ] Rotation tab only lists spells the character knows, at the best rank they have
- [ ] Level-up and learning a spell update the Rotation and Talents tabs (after combat)
- [ ] Healer specs show the Healing tab, tank specs show the Tanking tab, others show
      neither
- [ ] Theorycraft models read `data/stats/conversions.json`, not hard-coded numbers
- [ ] `/reload` with the addon on feels the same as with it off
