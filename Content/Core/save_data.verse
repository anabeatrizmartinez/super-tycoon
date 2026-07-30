using { /Verse.org/Simulation }

CurrentSaveVersion : int = 1

run_data<public> := class<final><persistable>:
    Version<public> : int = 1
    Gen<public>     : logic = false
    Wings<public>   : int = 0
    Guards<public>  : int = 0
    Gold<public>    : int = 0

var RunDataMap : weak_map(player, run_data) = map{}

LoadRunData<public>(Player : player)<decides><transacts> : run_data =
    Loaded := RunDataMap[Player]
    Loaded.Version <= CurrentSaveVersion
    Loaded

SaveRunData<public>(Player : player, Gen : logic, Wings : int, Guards : int, Gold : int) : void =
    Snapshot : run_data = run_data:
        Version := CurrentSaveVersion
        Gen := Gen
        Wings := Wings
        Guards := Guards
        Gold := Gold
    if (set RunDataMap[Player] = Snapshot) {}
