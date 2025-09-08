require ecs
require game.events.events
require game.es.entity_mods_common
require game.es.human.human_gun_common
require DngHuman


[es(on_event=EventOnModsChanged, on_appear)]
def gun_entity_loud_noise_per_shot_mult(evt : Event;
                                        var gun_entity_mods__loudNoisePerShotMult : float&;
                                        gun_entity_mods__loudNoisePerShotMods : Object)
  gun_entity_mods__loudNoisePerShotMult = calc_change_mult_attr(gun_entity_mods__loudNoisePerShotMods)


[es(on_event=EventOnModsChanged, on_appear)]
def gun_entity_damage_mult(evt : Event;
                           var gun_entity_mods__damageMult : float&;
                           gun_entity_mods__damageMods : Object)
  gun_entity_mods__damageMult = calc_change_mult_attr(gun_entity_mods__damageMods)


[es(on_event=EventOnModsChanged, on_appear)]
def gun_entity_mods_ads_speed_mult(evt : Event;
                                   var gun_entity_mods__adsSpeedMult : float&;
                                   gun_entity_mods__adsSpeedMods : Object)
  gun_entity_mods__adsSpeedMult = calc_change_mult_attr(gun_entity_mods__adsSpeedMods)
