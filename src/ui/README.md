# src/ui/

Scenes and screens. The UI plays back what the sim logs and never changes a fight (`CLAUDE.md` rule 2): `arena/FightPlayer` owns the sim and is the only thing that steps it. `CLAUDE.md`'s "How the UI works" maps each screen.

## Folders

| Folder | What it holds |
| --- | --- |
| `app/` | The app's frame: `Main`, the look, the art loader, and names for units in a fight. |
| `arena/` | The board: `ArenaView`, `UnitToken`, `FightFx`, `FightPlayer`, and `FigureArt`. |
| `info/` | The sentences and numbers lines the UI shows for kits and cards: `UnitInfo` and `ModInfo`, generated from the data. |
| `practice/` | `PracticeSession`: what Practice remembers while the game is open. |
| `run/` | `RunSession`: Practice's session over a `RunFlow`, so the arena, hero bar, and hero panel show the run's heroes; it saves after every action. |
| `screens/` | One `UiScreen` at a time: the title, Practice's encounter list, the arena, the run's start, and the run's day. |
| `widgets/` | The pieces screens are built from: the hero bar and panel, popups and hover cards, the log, the fight chart, banners, the act map, item icons, portraits, the shop stage, the tactic picker, and toasts. |
