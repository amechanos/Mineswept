# Mineswept
A 2D deckbuilding game built on a twisted Minesweeper concept

## Devlog
----------
### 27/04

**Board Generation**
Created a board that takes `w` and `h` as arguments that forms a grid of inputted size. Added probability approach to place down player attacks on the board in the form of 1s.

**Tile Map**
Created a simple tile map for the board, with a total of 12 states.

### 28/04

**Player**
Created player with basic step-based movement. Script acts purely as an input emitter — it knows nothing about the grid and only fires signals (`stepped`, `revealed`, `flagged`) when the player moves or interacts. 

**Global**
`board.gd` owns all game logic and responds to those signals. `Global.gd` holds shared state that both scripts need to read.

**Board generation**
Replaced the random per-tile probability approach with a shuffle pool system. All grid positions are collected into an array, shuffled, then the first 6 positions get player attacks (value `1`) and the next 6 get enemy attacks (value `2`). This guarantees exactly 6 of each with no overlaps.

**Tile Map / Logic**
`get_nearby_bombs` counts adjacent non-zero tiles and updates the tile map accordingly. Tiles with zero nearby attacks stay as BLANK rather than displaying a `0`, which also fixed the 400 atlas coordinate errors you were seeing on startup. Also added flagged state to tile.

**Tile state tracking**
Two dictionaries — `revealed_tiles` and `flagged_tiles` — prevent repeat interactions. Revealed tiles skip the stepped logic. Flagged tiles block accidental reveals. Flags toggle on and off, resetting to BLANK when removed.
