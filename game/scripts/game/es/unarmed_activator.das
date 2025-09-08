require ecs

[es(on_appear, REQUIRE=game_effect__activateUnarmed)]
def unarmed_activator_set_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_unarmed__active : bool&;
                                                 var human_unarmed__disableSwitchWeaponEffect : EntityId&)
    human_unarmed__disableSwitchWeaponEffect = createEntity("disabled_weapon_switch_game_effect") <| $(init)
      set(init, "game_effect__attachedTo", game_effect__attachedTo)
    human_unarmed__active = true

[es(on_disappear, REQUIRE=game_effect__activateUnarmed)]
def unarmed_activator_unset_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (human_unarmed__disableSwitchWeaponEffect : EntityId; var human_unarmed__active : bool&)
    human_unarmed__active = false
    destroyEntity(human_unarmed__disableSwitchWeaponEffect)

