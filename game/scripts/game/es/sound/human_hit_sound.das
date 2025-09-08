require ecs
require ecs.safe
require ecs.common
require app
require soundEvent
require soundHash
require soundProps
require game.events.sound_net_events
require sound_utils.modules.sound_player_common
require DngDm
require strings


def damage_type_to_sound_path(damage_type : int)
  if damage_type == int(DamageType.DM_MELEE) || damage_type == int(DamageType.DM_BACKSTAB)
    return "hit_dmgMelee"
  if damage_type == int(DamageType.DM_EXPLOSION)
    return "hit_dmgExplosion"
  if damage_type == int(DamageType.DM_HOLD_BREATH)
    return "hit_dmgAsphyxiation"
  return ""


def is_armored(parts_armor : FloatList const?; node_id : int; sound_tags : Object)
  return parts_armor != null ? (node_id >= 0 && node_id < length(*parts_armor) && (*parts_armor)[node_id] != 0.) : read_sound_tag("armored", sound_tags)



let MAX_NET_DELAY = 3.

[es(tag=sound, REQUIRE=humanSound)]
def human_hit_sound(evt : CmdHumanHitNetSound;
                    @shared_comp human_hit_sound__paths : Object;
                    is_watched_sound : bool;
                    sound_tags : Object;
                    var sound_event_group : SoundEventGroup&;
                    dm_parts__type : StringList const?;
                    dm_parts__partsArmor : FloatList const?;
                    isAlive : bool;
                    transform : float3x4)
  if get_sync_time() > evt.time + MAX_NET_DELAY
    return

  assume hitPos = transform[3]
  query(evt.offender) <| $ [es] (@shared_comp offender_hits_human_sound__path : Object)
    sound_player_common::play_path(offender_hits_human_sound__path, sound_tags, is_watched_sound, hitPos)

  if evt.damageType != int(DamageType.DM_PROJECTILE)
    var name, path : string
    if evt.actionPropsId >= 0
      action_sound_get_props(evt.actionPropsId) <| $(props : SoundActionProps)
        name = props.humanHitSoundName
        path = props.humanHitSoundPath
    if empty(path)
      path = damage_type_to_sound_path(evt.damageType)

    var pathObj = !empty(path) ? (human_hit_sound__paths[path] ?as Object) : null
    if pathObj != null
      let collNodeId = evt.collNodeId
      if dm_parts__type != null && uint(collNodeId) < uint(length(*dm_parts__type))
        let part = get_desc(*pathObj, "part_{(*dm_parts__type)[collNodeId]}")
        pathObj = part != null ? part : pathObj

      if get_option_path(pathObj, sound_tags, is_watched_sound, path)
        if empty(name)
          name = (*pathObj).name ?? ""
        var handle = play_name_path_impl(name, apply_watched_prefix(path, is_watched_sound), hitPos, false/*is_abandon*/)
        if evt.damageType == int(DamageType.DM_MELEE) || evt.damageType == int(DamageType.DM_BACKSTAB)
          if isAlive && is_armored(dm_parts__partsArmor, collNodeId, sound_tags)
            set_var_optional(handle, "armored", 1.)
        let localPos = inverse(transform) * hitPos
        if keyoff(handle)
          add_sound(sound_event_group, sound_hash("hit"), localPos, handle, 4/*max_instances*/)
          // expecting only "tinnitus" currently(it is keyoffable, nononeshot). added to group with label="hit" to release it immediately on soldier switch and on death.
          // also may add option to pathObj to specify if should add handle to group or not.
          // but should not release fast oneshot sounds such as bullet hit to hear it after death.
        else
          abandon(handle)


[es(tag=sound, REQUIRE=(humanSound, is_watched_sound, isAlive), track=(is_watched_sound, isAlive))]
def human_hit_sound_release_immediately(evt : Event;
                                        var sound_event_group : SoundEventGroup&)
  release_sound(sound_event_group, sound_hash("hit"))
