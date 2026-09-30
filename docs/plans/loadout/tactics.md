# Tactics (14)

**4 shards.** An order (how the hero behaves) plus a small payoff that applies while the hero follows it. Rank II after 60s of fighting while following the order, rank III after 180s more; time only counts while the order is active. Buying a copy skips a rank. Rules: `README.md`. Numbers are placeholders.

## Targeting

| Tactic | Order | Rank I | Rank II | Rank III |
| --- | --- | --- | --- | --- |
| **Casters first** *(built)* | Goes for the nearest caster or support first | +20% damage to them | +35% | The first hit on each caster Silences it for 1s |
| **Fliers first** | Goes for flying enemies first | +20% damage to fliers | +35% | The first hit on each flier grounds it for 2s |
| **Marked first** | Goes for Marked enemies first | +10 CRIT against Marked enemies | +20 CRIT | Crits on Marked enemies extend the Mark by 0.5s |
| **Finish them** | Goes for the lowest-HP enemy in reach | +15% damage to enemies below 50% HP | +25% | Kills refund 10 mana |
| **Break the line** | Goes for the enemy with the most DEF first | Hits ignore 20% of the target's DEF | 35% | The first hit on each target lowers its DEF by 10 for the rest of the fight |
| **Guard the weakest** | Goes for whoever is attacking your lowest-HP ally | +10 DEF while doing it | +20 DEF | The ally you're guarding gets +10 DEF too |

## Positioning

| Tactic | Order | Rank I | Rank II | Rank III |
| --- | --- | --- | --- | --- |
| **Hold your ground** *(built)* | Stays put until an enemy comes within 2 hexes | +20% attack speed while holding | +35% | Keeps half the bonus after moving out |
| **Plant your feet** *(built)* | Stops walking while an enemy is within 2 hexes | +10 DEF while stopped | +20 DEF | Also +10% ATK and MGK while stopped |
| **Keep your distance** | Backs away to stay at full range | +10% attack speed at full range | +20% | The first hit after backing away is a crit |
| **Stay with the tank** | Stays within 2 hexes of the ally with the most DEF | +10% DEF while in range | +20% | Regenerates 1% of max HP per second while in range |
| **Dive** | Walks past the front line to the farthest enemy | +20% ATK and MGK for the first 5s | For the first 8s | A kill during the dive restarts the timer |

## Signatures

| Tactic | Order | Rank I | Rank II | Rank III |
| --- | --- | --- | --- | --- |
| **Wait to heal** *(built)* | Holds a heal until an ally in reach is below 60% HP | The held heal is +15% stronger | +25%, and it waits for 70% instead | The held heal also cleanses one harmful status |
| **Wait for a crowd** | Holds an area signature until 3 enemies are in its reach, or every enemy still standing if fewer than 3 remain, for at most 4s | The held signature deals +20% damage | +30%, and it waits at most 3s | +10% more for each enemy hit past 3 |
| **Save it for the kill** | Holds a damage signature until its target is below 50% HP | The held signature deals +25% damage | +40% | A kill with it refunds 30% of its mana |

## Notes

- *(built)* marks tactics already in the game (`data/tactics.json`); their rank I matches what's built, except **Plant your feet**, which gains its payoff (+10 DEF while stopped).
- Stay with the tank's rank III doesn't let the tank take hits for you: that's Hearthwall's Guard, a path's key mechanic.
