require ecs


[es(on_appear,
  track=attachable_suit_controller__suitAnimcharEid, REQUIRE=(watchedByPlr, smartwatch_owner))]
def create_smartwatch_panel(evt : Event; attachable_suit_controller__suitAnimcharEid : EntityId)
  if !(attachable_suit_controller__suitAnimcharEid |> has("smartwatch_panel"))
    attachable_suit_controller__suitAnimcharEid |> addSubTemplate("dynamic_screen_smartwatch_panel")


[es(on_appear, REQUIRE=smartwatch_owner_suit, REQUIRE_NOT=smartwatch_panel)]
def create_smartwatch_panel_on_suit(evt : Event; eid : EntityId)
  eid |> addSubTemplate("dynamic_screen_smartwatch_panel")


[es(on_disappear, REQUIRE=watchedByPlr)]
def destroy_smartwatch_panel(evt : Event; attachable_suit_controller__suitAnimcharEid : EntityId)
  if attachable_suit_controller__suitAnimcharEid |> has("smartwatch_panel")
    attachable_suit_controller__suitAnimcharEid |> removeSubTemplate("dynamic_screen_smartwatch_panel")


[es(on_disappear, REQUIRE=(smartwatch_owner_suit, smartwatch_panel))]
def destroy_smartwatch_panel_on_suit(evt : Event; eid : EntityId)
  eid |> removeSubTemplate("dynamic_screen_smartwatch_panel")
