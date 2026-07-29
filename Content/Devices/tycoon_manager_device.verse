using { /Fortnite.com/Devices }
using { /Fortnite.com/Game }
using { /Verse.org/Simulation }
using { /Verse.org/Simulation/Tags }
using { /invaliddomain/SuperTycoon/Core }
using { /invaliddomain/SuperTycoon/UI }

GuardDefeatedMessage<localizes> : message = "Guard defeated"
AchievementMessage<localizes> : message = "Achievement unlocked — Lord of the Manor"

tycoon_manager_device := class(creative_device):

    @editable GeneratorTrigger : trigger_device = trigger_device{}
    @editable WingTriggers : []trigger_device = array{}
    @editable GeneratorBillboard : billboard_device = billboard_device{}
    @editable WingBillboards : []billboard_device = array{}
    @editable GuardSpawners : []guard_spawner_device = array{}
    @editable AccoladeMedium : accolades_device = accolades_device{}
    @editable AccoladeAchievement : accolades_device = accolades_device{}
    @editable HudMessage : hud_message_device = hud_message_device{}
    @editable PlayerSpawner : player_spawner_device = player_spawner_device{}

    Config : pad_config = pad_config{}

    var Gen : logic = false
    var Wings : int = 0
    var Guards : int = 0
    var Gold : int = 0

    var Player : ?player = false
    var Hud : ?hud = false
    var SpawnedGuards : int = 0

    var WingProps : [][]creative_prop = array{}
    var GeneratorPadProps : []creative_prop = array{}
    var WingPadProps : [][]creative_prop = array{}

    OnBegin<override>()<suspends> : void =
        CacheTags()
        HideAll()
        DisableAll()

        if (FirstPlayer := GetPlayspace().GetPlayers()[0]):
            StartRun(FirstPlayer)
        else:
            Agent := PlayerSpawner.SpawnedEvent.Await()
            if (SpawnedPlayer := player[Agent]):
                StartRun(SpawnedPlayer)

    PropsWithTag(Tag : tag) : []creative_prop =
        for (Obj : Self.FindCreativeObjectsWithTag(Tag), Prop := creative_prop[Obj]):
            Prop

    CacheTags() : void =
        set GeneratorPadProps = PropsWithTag(pad_generator{})
        set WingPadProps = array:
            PropsWithTag(pad_wing_1{})
            PropsWithTag(pad_wing_2{})
            PropsWithTag(pad_wing_3{})
            PropsWithTag(pad_wing_4{})
        set WingProps = array:
            PropsWithTag(wing_props_1{})
            PropsWithTag(wing_props_2{})
            PropsWithTag(wing_props_3{})
            PropsWithTag(wing_props_4{})

    HideAll() : void =
        for (WingPropSet : WingProps):
            for (WingProp : WingPropSet):
                WingProp.Hide()
        for (Prop : GeneratorPadProps):
            Prop.Hide()
        for (PadPropSet : WingPadProps):
            for (PadProp : PadPropSet):
                PadProp.Hide()

    DisableAll() : void =
        GeneratorTrigger.Disable()
        for (Trigger : WingTriggers):
            Trigger.Disable()
        for (Spawner : GuardSpawners):
            Spawner.Disable()
        GeneratorBillboard.SetText(BlankLabel)
        GeneratorBillboard.HideText()
        for (Billboard : WingBillboards):
            Billboard.SetText(BlankLabel)
            Billboard.HideText()

    GeneratorPadOpen()<decides><transacts> : void =
        not Gen?

    WingPadOpen(Index : int)<decides><transacts> : void =
        Gen?
        Wings = Index
        Guards >= GuardsRequiredForWing(Index)

    # Wing 3 is the only pad behind a guard; wing 4's guard comes after it.
    GuardsRequiredForWing(Index : int)<computes> : int =
        if (Index = 2) then 1 else 0

    StartRun(NewPlayer : player) : void =
        set Player = option{NewPlayer}

        if (Loaded := LoadRunData[NewPlayer]):
            set Gen = Loaded.Gen
            set Wings = Loaded.Wings
            set Guards = Loaded.Guards
            set Gold = Loaded.Gold
        else:
            set Gold = StartingGold

        NewHud := MakeHud()
        NewHud.Attach(NewPlayer)
        set Hud = option{NewHud}
        PlayerSpawner.SpawnedEvent.Subscribe(OnPlayerSpawned)

        GeneratorTrigger.TriggeredEvent.Subscribe(OnGeneratorTriggered)
        if (Trigger := WingTriggers[0]):
            Trigger.TriggeredEvent.Subscribe(OnWing1Triggered)
        if (Trigger := WingTriggers[1]):
            Trigger.TriggeredEvent.Subscribe(OnWing2Triggered)
        if (Trigger := WingTriggers[2]):
            Trigger.TriggeredEvent.Subscribe(OnWing3Triggered)
        if (Trigger := WingTriggers[3]):
            Trigger.TriggeredEvent.Subscribe(OnWing4Triggered)
        if (Spawner := GuardSpawners[0]):
            Spawner.EliminatedEvent.Subscribe(OnGuard1Eliminated)
        if (Spawner := GuardSpawners[1]):
            Spawner.EliminatedEvent.Subscribe(OnGuard2Eliminated)

        RefreshWorld()
        RefreshHud()

        if (Gen?):
            spawn{ RunIncomeLoop() }

    RefreshWorld() : void =
        if (GeneratorPadOpen[]):
            for (Prop : GeneratorPadProps):
                Prop.Show()
            GeneratorBillboard.SetText(PadLabel(Config.GeneratorPad.Name, Config.GeneratorPad.Cost))
            GeneratorBillboard.ShowText()
            GeneratorTrigger.Enable()
        else:
            for (Prop : GeneratorPadProps):
                Prop.Hide()
            GeneratorBillboard.SetText(BlankLabel)
            GeneratorBillboard.HideText()
            GeneratorTrigger.Disable()

        for (Index -> PadProps : WingPadProps):
            if (Billboard := WingBillboards[Index], Trigger := WingTriggers[Index]):
                if (WingPadOpen[Index]):
                    for (Prop : PadProps):
                        Prop.Show()
                    if (Info := Config.WingPads[Index]):
                        Billboard.SetText(PadLabel(Info.Name, Info.Cost))
                    Billboard.ShowText()
                    Trigger.Enable()
                else:
                    for (Prop : PadProps):
                        Prop.Hide()
                    Billboard.SetText(BlankLabel)
                    Billboard.HideText()
                    Trigger.Disable()

        for (Index -> PropSet : WingProps):
            if (Wings > Index):
                for (Prop : PropSet):
                    Prop.Show()
            else:
                for (Prop : PropSet):
                    Prop.Hide()

        # Wing 3's guard gates wing 4; wing 4 has no gate of its own to spawn.
        if (Wings = 2, Guards = 0, SpawnedGuards = 0, Spawner := GuardSpawners[0]):
            Spawner.Enable()
            Spawner.Spawn()
            set SpawnedGuards += 1
        if (Wings = 4, Guards = 1, SpawnedGuards = 1, Spawner := GuardSpawners[1]):
            Spawner.Enable()
            Spawner.Spawn()
            set SpawnedGuards += 1

    RefreshHud() : void =
        if (ActiveHud := Hud?):
            ActiveHud.Refresh(Gold, Wings, Guards)

    OnGeneratorTriggered(Agent : ?agent) : void =
        if (GeneratorPadOpen[], Gold >= Config.GeneratorPad.Cost, ActivePlayer := Player?):
            set Gold -= Config.GeneratorPad.Cost
            set Gen = true
            SaveRunData(ActivePlayer, Gen, Wings, Guards, Gold)
            RefreshWorld()
            RefreshHud()
            spawn{ RunIncomeLoop() }

    OnWingTriggered(Index : int) : void =
        if (WingPadOpen[Index], Info := Config.WingPads[Index], Gold >= Info.Cost, ActivePlayer := Player?):
            set Gold -= Info.Cost
            set Wings += 1
            SaveRunData(ActivePlayer, Gen, Wings, Guards, Gold)
            RefreshWorld()
            RefreshHud()
            AccoladeMedium.Award(ActivePlayer)

    OnWing1Triggered(Agent : ?agent) : void = OnWingTriggered(0)
    OnWing2Triggered(Agent : ?agent) : void = OnWingTriggered(1)
    OnWing3Triggered(Agent : ?agent) : void = OnWingTriggered(2)
    OnWing4Triggered(Agent : ?agent) : void = OnWingTriggered(3)

    OnGuardEliminated(Index : int) : void =
        if (Guards = Index, ActivePlayer := Player?):
            set Guards += 1
            SaveRunData(ActivePlayer, Gen, Wings, Guards, Gold)

            HudMessage.SetText(GuardDefeatedMessage)
            HudMessage.Show(ActivePlayer)

            RefreshWorld()
            RefreshHud()

            if (Wings = 4, Guards = 2):
                HudMessage.SetText(AchievementMessage)
                HudMessage.Show(ActivePlayer)
                AccoladeAchievement.Award(ActivePlayer)

    OnGuard1Eliminated(Result : device_ai_interaction_result) : void = OnGuardEliminated(0)
    OnGuard2Eliminated(Result : device_ai_interaction_result) : void = OnGuardEliminated(1)

    OnPlayerSpawned(Agent : agent) : void =
        if (ActivePlayer := Player?, ActivePlayer = player[Agent]):
            RefreshHud()

    RunIncomeLoop()<suspends> : void =
        loop:
            Sleep(IncomeTickSeconds)
            set Gold += IncomePerTick
            RefreshHud()
