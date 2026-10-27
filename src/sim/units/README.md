# src/sim/units/

What units do each tick beyond moving: passives and their events (the chains), signatures and mana, statuses, deeds counted during a fight, tactics, gambits, grips, copied signatures, boss phases, and keywords.

## Files

| File | What it is |
| --- | --- |
| `copies.gd` | Copying a signature. |
| `deeds.gd` | Counts deeds as a fight runs. |
| `events.gd` | A unit's events, read from the combat log. |
| `gambits.gd` | Gambits in a fight: placement and fight-start rules, read from the kit. |
| `grips.gd` | A signature that grips its target: AbilityDef's "grip". |
| `keywords.gd` | Keywords: names for a unit's state that any card can refer to. |
| `mana.gd` | Mana, for units with a mana bar. |
| `passives.gd` | Passives in a fight. |
| `phases.gd` | Phases in a fight. |
| `signatures.gd` | Signatures and their triggers. |
| `statuses.gd` | Applies, ticks, and reads statuses. |
| `tactics.gd` | What a hero's tactic does in a fight. |
| `unit_turn.gd` | One standing unit's turn in a tick, for CombatSim.step: mana, its signature, Stun, its attack's cooldown, its target, then attacking or walking. |
