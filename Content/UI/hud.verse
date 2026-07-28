using { /Fortnite.com/Game }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /invaliddomain/SuperTycoon/Assets }

GoldLabel<internal><localizes>(Amount : int) : message = "{Amount} Gold"
AchievementName<internal><localizes> : message = "Lord of the Manor"
AchievementLocked<internal><localizes> : message = "Lord of the Manor — LOCKED\nRestore all four wings and clear both guards."
AchievementEarned<internal><localizes> : message = "Lord of the Manor — EARNED"

HudWhite<internal> : color = NamedColors.White

MakeHud<public>() : hud =
    GoldIcon := texture_block{DefaultImage := gold}

    GoldText := text_block{DefaultText := GoldLabel(0)}
    GoldText.SetTextColor(HudWhite)

    AchievementIcon := texture_block{DefaultImage := achievement}

    AchievementsButton := button_loud{DefaultText := AchievementName}

    AchievementRow := text_block{DefaultText := AchievementLocked}
    AchievementRow.SetTextColor(HudWhite)
    AchievementRow.SetVisibility(widget_visibility.Collapsed)

    GoldRow := stack_box:
        Orientation := orientation.Horizontal
        Slots := array:
            stack_box_slot{Widget := GoldIcon, Padding := margin{Right := 8.0}}
            stack_box_slot{Widget := GoldText}

    ButtonRow := stack_box:
        Orientation := orientation.Horizontal
        Slots := array:
            stack_box_slot{Widget := AchievementIcon, Padding := margin{Right := 6.0}}
            stack_box_slot{Widget := AchievementsButton}

    ReadoutCanvas := canvas:
        Slots := array:
            canvas_slot:
                Widget := GoldRow
                Anchors := anchors{Minimum := vector2{X := 0.0, Y := 1.0}, Maximum := vector2{X := 0.0, Y := 1.0}}
                Alignment := vector2{X := 0.0, Y := 1.0}
                Offsets := margin{Left := 48.0, Bottom := 200.0}

    ControlCanvas := canvas:
        Slots := array:
            canvas_slot:
                Widget := ButtonRow
                Anchors := anchors{Minimum := vector2{X := 1.0, Y := 0.5}, Maximum := vector2{X := 1.0, Y := 0.5}}
                Alignment := vector2{X := 1.0, Y := 0.5}
                Offsets := margin{Right := 48.0}
            canvas_slot:
                Widget := AchievementRow
                Anchors := anchors{Minimum := vector2{X := 1.0, Y := 0.5}, Maximum := vector2{X := 1.0, Y := 0.5}}
                Alignment := vector2{X := 1.0, Y := 0.5}
                Offsets := margin{Right := 48.0, Top := 48.0}

    Hud := hud:
        GoldText := GoldText
        AchievementsButton := AchievementsButton
        AchievementRow := AchievementRow
        ReadoutCanvas := ReadoutCanvas
        ControlCanvas := ControlCanvas

    Hud.AchievementsButton.OnClick().Subscribe(Hud.OnAchievementsClicked)

    Hud

hud<public> := class:
    GoldText<public>          : text_block
    AchievementsButton<public>: button_loud
    AchievementRow<public>    : text_block
    ReadoutCanvas<public>     : canvas
    ControlCanvas<public>     : canvas
    var PanelVisible<public>  : logic = false

    Attach<public>(Player : player) : void =
        if (PlayerUI := GetPlayerUI[Player]):
            PlayerUI.RemoveWidget(ReadoutCanvas)
            PlayerUI.RemoveWidget(ControlCanvas)
            PlayerUI.AddWidget(ReadoutCanvas, player_ui_slot{InputMode := ui_input_mode.None})
            PlayerUI.AddWidget(ControlCanvas, player_ui_slot{InputMode := ui_input_mode.All})

    Refresh<public>(Gold : int, Wings : int, Guards : int) : void =
        GoldText.SetText(GoldLabel(Gold))

        if (Wings = 4, Guards = 2):
            AchievementRow.SetText(AchievementEarned)
        else:
            AchievementRow.SetText(AchievementLocked)

    OnAchievementsClicked<internal>(Message : widget_message) : void =
        if (PanelVisible?):
            set PanelVisible = false
            AchievementRow.SetVisibility(widget_visibility.Collapsed)
        else:
            set PanelVisible = true
            AchievementRow.SetVisibility(widget_visibility.Visible)
