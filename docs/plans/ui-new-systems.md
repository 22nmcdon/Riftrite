# UI for the new systems

Status: **agreed in discussion (2026-09-30), not built.** What the UI must show for the systems designed on 2026-09-30. **An overall UI redesign comes next:** it decides the layout, and it must cover everything here. Where this file names a place (hover card, hero sheet, result screen, fight card), that's where the information belongs, not a fixed layout.

## 1. Items and ranks

| What | How it shows |
| --- | --- |
| **Rank** | Roman numeral pips (I, II, III) on the item frame's corner |
| **Progress to the next rank** | A thin ring around the icon that fills; the hover card says what's left ("Rank II in 3 more won fights") |
| **Ranking up** | On the result screen, the item flashes and shows "Rank II" |
| **Buying a copy** | The shop card says "You own this: buying skips it to Rank III" |
| **Selling** | Drag an item onto the shop's coin dish, or use the hover card's Sell button, which shows its price. The Magpie's dish takes only relics |
| **Kinds** | Tactics, gambits, sigils, and charms each keep their own frame shape. **The graft frame is retired** (grafts are cut; `magpie.md`) |

## 2. Gambits

- **Placement:** dragging a hero who holds a gambit lights up the extra hexes it allows (the middle row for Infiltrate, behind your zone for Rear Guard, edge hexes for Late Arrival).
- **Choices:** Switch Places' timing and Late Arrival's entry hex are set on the hero during placement.
- **One per hero:** a second gambit shows greyed on that hero, with "One gambit per hero".

## 3. Shop and rerolls

- **Reroll** is a lever with a price tag showing the next reroll's cost; the tag goes up after each pull. In the pre-boss shop it starts at 5.
- **The relic slot** has a frame for each tier. A bond relic has its own frame and a "Free" tag.
- **The Magpie's stall** shows "One look" in place of a reroll lever.

## 4. Upgrades, growth, and deeds

| What | How it shows |
| --- | --- |
| **Growing upgrades and relics** | The card shows the current value with a small "grows" mark ("+14% ATK"); the hover card shows progress to the next step ("412 / 500 damage") |
| **Growth after a fight** | The result screen lists what grew ("Notched Bow: +1% ATK") |
| **Stacking upgrades** | On the hero sheet, the upgrade shows how many times it's been taken; the hover card lists each locked-in amount ("Honed Tips ×3: +2, +3, +5 ATK") |
| **Deeds** | The hero sheet shows the path deed bar, then the apex deed bar once the apex vow is made |
| **Snowballs during a fight** | **Behind the testing toggle only** (decided 2026-09-30), with the combo readouts: a status tag with a number on the unit, like Burn stacks ("Windrunner +27%"). Players see the snowball only in what it does |

- ~~**The snowball tag isn't a combo readout:** it shows the state a unit is in, like any status, never a damage breakdown (part 7, section 7).~~ Decided (2026-09-30): it goes behind the testing toggle with the combo readouts.

## 5. Vows and bonds

- **The vow screen:** vowing two heroes to bonded paths shows a "?" link between their portraits. Its name shows once the bond switches on.
- **Once it's on:** the bond shows on both heroes' sheets, with "Its relic is in the shop pool now".

## 6. The fight card

- **Specializations:** a badge on the enemy's portrait, and the name in its threat line ("Burrowing Pup: surfaces behind your back line").
- **Upgrades:** small icons under the enemy's portrait.
- **Rift modifiers:** a banner row of icons across the top of the card.
- **Counters from the rift learns:** an eye mark on each one, so the player sees the rift answering them.

## Open questions

- All layout questions go to the overall UI redesign.
