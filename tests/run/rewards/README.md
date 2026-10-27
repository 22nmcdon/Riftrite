# tests/run/rewards/

What a run earns and spends: the economy, relics, the loadout, growing cards, the upgrade pools, apexes and their cards, Tithe, and transmuting.

## Files

| File | What it is |
| --- | --- |
| `test_apex_cards.gd` | The apex cards: every apex has two; they're offered only once that apex is earned and count only on it; the knobs they needed change what they name; and on_rise sets off Dread Return in a fight. |
| `test_apexes.gd` | Apexes in the run: the apex vow opens going deeper, only for transformed heroes whose path has apexes, and later for a late transformer; switching is free until the apex is earned; the apex deed fills and raises the hero; the fight takes the apex's kit;... |
| `test_economy.gd` | The economy in a run: items as data, the loadout, the Pedlar and the Magpie, treating wounds, and items reaching the fight. |
| `test_growth.gd` | Growth in a run: deed thresholds and transformations, Switch vow, the upgrades as data, and the after-fight pick. |
| `test_growth_cards.gd` | Growing cards: a step's mod times the steps, the cards as data, counting in the run from when a card is taken, a relic's team count, a quest's cap, the save, and the lines the cards show. |
| `test_loadout.gd` | The loadout pool's frame: ranks and each kind's counter, a bought copy a rank up, rank III never in a shop, selling at half, prices by kind, one gambit per hero, ranks in the fight and in the save, and the tallies a real fight counts for a tactic and a sigil. |
| `test_relics.gd` | The relic pool's first part: the tiers, every 5a relic's effect, the run rules, the shops' relics and rerolls, the boss shop, and the boss relic choice. |
| `test_tithe.gd` | Edric's run pieces: Tithe paid after a won day fight for each hero standing, its deed counted by the run, Collection's shards from a fight, the shards held passed to the fight, the apexes' run snowballs on flawless fights, Ward Tax's shards needed, Ledger... |
| `test_transmute.gd` | Transmuting: once a shop, at the Pedlar or the boss shop, a transformed Transmuter turns an item the run owns into shards at its full price; Appraise pays more for ranks II and III; never at the Magpie, never before she transforms; the count survives a... |
| `test_upgrade_pools.gd` | The upgrade pools: what each hero is offered by stage, cards that would change nothing, and stacking cards' lock-in. |
