using { /Fortnite.com/Game }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /invaliddomain/SuperTycoon/Assets }

GoldLabel<internal><localizes>(Amount : int) : message = "{Amount}"
AchievementName<internal><localizes> : message = "Lord of the Manor"
AchievementCondition<internal><localizes> : message = "Restore the Manor and clear the guards."
AchievementLocked<internal><localizes> : message = "LOCKED"
AchievementEarned<internal><localizes> : message = "EARNED"

AchievementFill<internal> : color = MakeColorFromSRGB(0.48, 0.18, 0.75) #7a2ebf
GoldFill<internal> : color = MakeColorFromSRGB(0.96, 0.71, 0.14) #f5b524
BadgeRimColor<internal> : color = NamedColors.White

BadgeText<internal> : color = NamedColors.White

IconSize<internal> : vector2 = vector2{X := 32.0, Y := 32.0}
AchievementIconSize<internal> : vector2 = vector2{X := 28.0, Y := 28.0}

NameTextSize<internal> : float = 20.0
DetailTextSize<internal> : float = 13.0

ConditionWrapWidth<internal> : float = 180.0

ScreenEdgeGap<internal> : float = 24.0

BadgeRim<internal>() : margin = margin{Left := 3.0, Top := 3.0, Right := 3.0, Bottom := 3.0}

BadgePadding<internal>() : margin = margin{Left := 14.0, Top := 8.0, Right := 18.0, Bottom := 8.0}

MakeBadge<internal>(Fill : color, Content : widget) : overlay =
    overlay:
        Slots := array:
            overlay_slot:
                Widget := color_block{DefaultColor := BadgeRimColor}
                HorizontalAlignment := horizontal_alignment.Fill
                VerticalAlignment := vertical_alignment.Fill
            overlay_slot:
                Widget := color_block{DefaultColor := Fill}
                HorizontalAlignment := horizontal_alignment.Fill
                VerticalAlignment := vertical_alignment.Fill
                Padding := BadgeRim()
            overlay_slot:
                Widget := Content
                Padding := BadgePadding()

MakeHud<public>() : hud =
    GoldText := text_block{DefaultText := GoldLabel(0)}
    GoldText.SetTextColor(BadgeText)
    GoldIcon := texture_block{DefaultImage := gold, DefaultDesiredSize := IconSize}

    GoldRow := stack_box:
        Orientation := orientation.Horizontal
        Slots := array:
            stack_box_slot:
                Widget := GoldIcon
                Padding := margin{Right := 10.0}
                VerticalAlignment := vertical_alignment.Center
            stack_box_slot:
                Widget := GoldText
                VerticalAlignment := vertical_alignment.Center

    GoldBadge := MakeBadge(GoldFill, GoldRow)

    AchievementIcon := texture_block{DefaultImage := achievement, DefaultDesiredSize := AchievementIconSize}
    AchievementNameText := text_block{DefaultText := AchievementName}
    AchievementNameText.SetTextColor(BadgeText)
    AchievementNameText.SetTextSize(NameTextSize)

    NameRow := stack_box:
        Orientation := orientation.Horizontal
        Slots := array:
            stack_box_slot:
                Widget := AchievementIcon
                Padding := margin{Right := 8.0}
                VerticalAlignment := vertical_alignment.Center
            stack_box_slot:
                Widget := AchievementNameText
                VerticalAlignment := vertical_alignment.Center

    AchievementConditionText := text_block{DefaultText := AchievementCondition, AutoWrap := true, WrapWidth := ConditionWrapWidth, DefaultJustification := text_justification.Center}
    AchievementConditionText.SetTextColor(BadgeText)
    AchievementConditionText.SetTextSize(DetailTextSize)

    AchievementStatusText := text_block{DefaultText := AchievementLocked}
    AchievementStatusText.SetTextColor(BadgeText)
    AchievementStatusText.SetTextSize(DetailTextSize)

    AchievementColumn := stack_box:
        Orientation := orientation.Vertical
        Slots := array:
            stack_box_slot:
                Widget := NameRow
                Padding := margin{Bottom := 4.0}
            stack_box_slot:
                Widget := AchievementConditionText
                Padding := margin{Bottom := 2.0}
                HorizontalAlignment := horizontal_alignment.Center
            stack_box_slot:
                Widget := AchievementStatusText
                HorizontalAlignment := horizontal_alignment.Center

    AchievementBadge := MakeBadge(AchievementFill, AchievementColumn)

    ReadoutCanvas := canvas:
        Slots := array:
            canvas_slot:
                Widget := GoldBadge
                Anchors := anchors{Minimum := vector2{X := 0.0, Y := 0.5}, Maximum := vector2{X := 0.0, Y := 0.5}}
                Alignment := vector2{X := 0.0, Y := 0.5}
                Offsets := margin{Left := ScreenEdgeGap}
            canvas_slot:
                Widget := AchievementBadge
                Anchors := anchors{Minimum := vector2{X := 1.0, Y := 0.5}, Maximum := vector2{X := 1.0, Y := 0.5}}
                Alignment := vector2{X := 1.0, Y := 0.5}
                Offsets := margin{Left := -ScreenEdgeGap}

    hud:
        GoldText := GoldText
        AchievementStatusText := AchievementStatusText
        ReadoutCanvas := ReadoutCanvas

hud<public> := class:
    GoldText<public>              : text_block
    AchievementStatusText<public> : text_block
    ReadoutCanvas<public>         : canvas

    Attach<public>(Player : player) : void =
        if (PlayerUI := GetPlayerUI[Player]):
            PlayerUI.RemoveWidget(ReadoutCanvas)
            PlayerUI.AddWidget(ReadoutCanvas, player_ui_slot{InputMode := ui_input_mode.None})

    Refresh<public>(Gold : int, Wings : int, Guards : int) : void =
        GoldText.SetText(GoldLabel(Gold))

        if (Wings = 4, Guards = 2):
            AchievementStatusText.SetText(AchievementEarned)
        else:
            AchievementStatusText.SetText(AchievementLocked)
