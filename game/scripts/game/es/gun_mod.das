require ecs
require ecs.common
require DagorMath
require game.events.events


[es(tag=server, on_appear, track=slot_attach__attachedTo)]
def gun_mod_with_effect_appear(evt : Event;
                               slot_attach__attachedTo : EntityId;
                               gun_mod__effectTemplate : string;
                               var gun_mod__effectEid : EntityId&)
  if slot_attach__attachedTo == INVALID_ENTITY_ID && gun_mod__effectEid == INVALID_ENTITY_ID
    return

  if gun_mod__effectEid != INVALID_ENTITY_ID
    destroyEntity(gun_mod__effectEid)

  gun_mod__effectEid = createEntity(gun_mod__effectTemplate) <| $ [es] (var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", slot_attach__attachedTo)


[es(tag=server, on_disappear, REQUIRE=slot_attach__attachedTo)]
def gun_mod_with_effect_disappear(evt : Event;
                                  gun_mod__effectEid : EntityId)
  destroyEntity(gun_mod__effectEid)



[es(on_appear, REQUIRE=gun_mod_effect)]
def gun_mod_effect_appear(evt : Event;
                          eid aka gun_mod_effect_eid : EntityId;
                          game_effect__attachedTo : EntityId;
                          gun_mod_effect__loudNoisePerShotMult : float const?;
                          gun_mod_effect__damageMult : float const?;
                          gun_mod_effect__adsSpeedMult : float const?)
  query(game_effect__attachedTo) <| $ [es] (var gun_entity_mods__loudNoisePerShotMods : Object;
                                            var gun_entity_mods__damageMods : Object;
                                            var gun_entity_mods__adsSpeedMods : Object)
    let eidPrefix = "{gun_mod_effect_eid}"

    if gun_mod_effect__loudNoisePerShotMult != null
      gun_entity_mods__loudNoisePerShotMods |> set(eidPrefix, *gun_mod_effect__loudNoisePerShotMult)

    if gun_mod_effect__damageMult != null
      gun_entity_mods__damageMods |> set(eidPrefix, *gun_mod_effect__damageMult)

    if gun_mod_effect__adsSpeedMult != null
      gun_entity_mods__adsSpeedMods |> set(eidPrefix, *gun_mod_effect__adsSpeedMult)

    sendEvent(game_effect__attachedTo, EventOnModsChanged())


[es(on_disappear, REQUIRE=gun_mod_effect)]
def gun_mod_effect_disappear(evt : Event;
                             eid aka gun_mod_effect_eid : EntityId;
                             game_effect__attachedTo : EntityId;
                             gun_mod_effect__loudNoisePerShotMult : float const?;
                             gun_mod_effect__damageMult : float const?;
                             gun_mod_effect__adsSpeedMult : float const?)
  query(game_effect__attachedTo) <| $ [es] (var gun_entity_mods__loudNoisePerShotMods : Object;
                                            var gun_entity_mods__damageMods : Object;
                                            var gun_entity_mods__adsSpeedMods : Object)
    let eidPrefix = "{gun_mod_effect_eid}"

    if gun_mod_effect__loudNoisePerShotMult != null
      gun_entity_mods__loudNoisePerShotMods |> erase(eidPrefix)

    if gun_mod_effect__damageMult != null
      gun_entity_mods__damageMods |> erase(eidPrefix)

    if gun_mod_effect__adsSpeedMult != null
      gun_entity_mods__adsSpeedMods |> erase(eidPrefix)

    sendEvent(game_effect__attachedTo, EventOnModsChanged())


[es(on_appear, REQUIRE=gun_mod_effect__gunFlashFxDisabler)]
def gun_mod_effect_flash_fx_disabler_appear(evt : Event;
                                            game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var gun_flash_fx__enabled : bool&)
    gun_flash_fx__enabled = false


[es(on_disappear, REQUIRE=gun_mod_effect__gunFlashFxDisabler)]
def gun_mod_effect_flash_fx_disabler_disappear(evt : Event;
                                               game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var gun_flash_fx__enabled : bool&)
    gun_flash_fx__enabled = true
