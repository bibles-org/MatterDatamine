require ecs
require ecs.safe
require soundEvent
require sound_utils.modules.sound_player_common
require game.es.sound.gun_sound_common
require strings


def gather_gun_shot_paths(shot_path : Object; is_watched : bool; var paths : array<string>&)
  for idx in range(0, get_num_option_paths(shot_path))
    paths |> push(make_gun_shot_sound_path_str(shot_path, idx, is_watched, false))
    paths |> push(make_gun_shot_sound_path_str(shot_path, idx, is_watched, true))


def gather_gun_reload_paths(reload_path : Object; is_watched : bool; var paths : array<string>&)
  for it in reload_path
    let irqObj = it.value as Object
    if irqObj != null
      for idx in range(0, get_num_option_paths(*irqObj))
        paths |> push(make_final_path_str(*irqObj, idx, is_watched))


def human_preload_gun_sounds(gun_eid, human_eid : EntityId;
                             human_sound_tags : Object;
                             is_preset_loaded, is_alive, is_watched : bool;
                             var preload : SoundEventsPreload&)
  var paths : array<string>
  if is_preset_loaded && is_alive && is_watched
    query(gun_eid) <| $ [es] (@shared_comp gun_sound__shotPath : Object)
      gather_gun_shot_paths(gun_sound__shotPath, is_watched, paths)
    query(gun_eid) <| $ [es] (@shared_comp sound_irqs : Object)
      gather_gun_reload_paths(sound_irqs, is_watched, paths)

    // melee weapon events
    query(gun_eid) <| $ [es] (meleeSoundType : string = "hands")
      if empty(meleeSoundType)
        return
      query(human_eid) <| $ [es] (@shared_comp human_melee_sound__irqs : Object)
        for it in human_melee_sound__irqs
          let irqObj = it.value as Object
          if irqObj != null
            let weapon = (irqObj?.weapons ?as Object)?[meleeSoundType] ?as Object
            if weapon != null
              var path : string
              if get_option_path(*weapon, human_sound_tags, is_watched, path)
                paths |> push(apply_watched_prefix(path, is_watched))

  preload |> sound_events_load(paths)


[es(tag=sound, on_appear, track=(human_weap__currentGunEid, human_attached_gun__attachedGunEid, is_watched_sound, sound_banks_state__isPresetLoaded, sound_tags, isAlive))]
def human_gun_sounds_preload(evt : Event;
                             eid aka human_eid : EntityId;
                             sound_tags aka human_sound_tags : Object;
                             human_weap__currentGunEid : EntityId;
                             human_attached_gun__attachedGunEid : EntityId;
                             var human_gun_sounds_preload : SoundEventsPreload&;
                             sound_banks_state__isPresetLoaded : bool;
                             is_watched_sound : bool;
                             isAlive : bool)

  let gunEid = human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid
  human_preload_gun_sounds(gunEid, human_eid, human_sound_tags, sound_banks_state__isPresetLoaded, isAlive, is_watched_sound, human_gun_sounds_preload)


[es(tag=sound, on_appear, track=gun__owner)]
def human_gun_sounds_preload_on_gun_appear(evt : Event;
                                           eid : EntityId;
                                           gun__owner : EntityId)

  query(gun__owner) <| $ [es] (sound_tags aka human_sound_tags : Object;
                               human_weap__currentGunEid : EntityId;
                               human_attached_gun__attachedGunEid : EntityId;
                               var human_gun_sounds_preload : SoundEventsPreload&;
                               sound_banks_state__isPresetLoaded : bool;
                               is_watched_sound : bool;
                               isAlive : bool)

    let gunEid = human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid
    if gunEid == eid
      human_preload_gun_sounds(gunEid, gun__owner, human_sound_tags, sound_banks_state__isPresetLoaded, isAlive, is_watched_sound, human_gun_sounds_preload)


// vehicle ---------------------->

[es(tag=sound, on_appear, track=(is_watched_sound, sound_banks_state__isPresetLoaded, isAlive))]
def vehicle_gun_sounds_preload(evt : Event;
                               var vehicle_gun_sounds_preload : SoundEventsPreload&;
                               sound_banks_state__isPresetLoaded : bool;
                               is_watched_sound : bool;
                               isAlive : bool;
                               turret_control__gunEids : EidList)

  var paths : array<string>
  if sound_banks_state__isPresetLoaded && isAlive && is_watched_sound
    for gunEid in turret_control__gunEids
      query(gunEid) <| $ [es] (@shared_comp gun_sound__shotPath : Object)
        gather_gun_shot_paths(gun_sound__shotPath, is_watched_sound, paths)
      query(gunEid) <| $ [es] (@shared_comp sound_irqs : Object)
        gather_gun_reload_paths(sound_irqs, is_watched_sound, paths)
  vehicle_gun_sounds_preload |> sound_events_load(paths)
