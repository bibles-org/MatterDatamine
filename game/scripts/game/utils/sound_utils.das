module sound_utils shared

require ecs
require ecs.safe
require app
require game.utils.net_utils
require game.utils.team
require player public
require DngNet
require soundHash
require soundSystem
require sound_utils_net.modules.sound_utils_net_events


def private get_desc(name : string; descs : Object; should_exist : bool) : Object const?
  let desc = descs[name] ?as Object
  if should_exist && desc == null
    sound_debug("net_sound: sound '{name}' not found in net_sound.descs {descs}")
  return desc


def private is_valid(desc : Object const?)
  return desc != null && (has(*desc, "path") || has(*desc, "hero") || has(*desc, "enemy"))

// ....................................................
//
// ....................................................

def send_net_sound(target : EntityId;
                   name : string;
                   param : float = 0.;
                   should_exist = true;
                   need_connections = false)
  query(target) <| $ [es] (@shared_comp net_sound__descs : Object)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let connections = target_entity_conn(target)
      if !need_connections || !empty(connections)
        send_net_event(target, CmdPlayNetSound(hash = sound_hash(name), param = param, time = get_sync_time()), connections)


def send_net_sound(target : EntityId;
                   name : string;
                   pos : float3;
                   param : float = 0.;
                   should_exist = true;
                   need_connections = false)
  query(target) <| $ [es] (@shared_comp net_sound__descs : Object)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let connections = target_entity_conn(target)
      if !need_connections || !empty(connections)
        send_net_event(target, CmdPlayNetSoundPos(hash = sound_hash(name), pos = pos, param = param, time = get_sync_time()), connections)

// ....................................................
//
// ....................................................

def broadcast_net_sound(target : EntityId;
                        name : string;
                        param : float = 0.;
                        only_for_team_id = TEAM_UNASSIGNED;
                        only_for_squad_eid = INVALID_ENTITY_ID;
                        except_possessed = INVALID_ENTITY_ID;
                        should_exist = true;
                        need_connections = false)
  query(target) <| $ [es] (@shared_comp net_sound__descs : Object; transform : float3x4)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let searchRange : float = *desc |> get_float("range") ?? 0./*unlimited*/
      let pos = transform[3]
      let connections = enum_connections_near_pos(pos, searchRange, only_for_team_id, only_for_squad_eid, except_possessed)
      if !need_connections || !empty(connections)
        send_net_event(target, CmdPlayNetSound(hash = sound_hash(name), param = param, time = get_sync_time()), connections)


def broadcast_net_sound(target : EntityId;
                        name : string;
                        pos : float3;
                        param : float = 0.;
                        only_for_team_id = TEAM_UNASSIGNED;
                        only_for_squad_eid = INVALID_ENTITY_ID;
                        except_possessed = INVALID_ENTITY_ID;
                        should_exist = true;
                        need_connections = false)
  query(target) <| $ [es] (@shared_comp net_sound__descs : Object)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let searchRange : float = *desc |> get_float("range") ?? 0./*unlimited*/
      let connections = enum_connections_near_pos(pos, searchRange, only_for_team_id, only_for_squad_eid, except_possessed)
      if !need_connections || !empty(connections)
        send_net_event(target, CmdPlayNetSoundPos(hash = sound_hash(name), pos = pos, param = param, time = get_sync_time()), connections)

// ....................................................
//
// ....................................................

def send_scene_net_sound(target : EntityId; name : string; need_connections = false)
  var numSounds = 0
  query() <| $ [es(REQUIRE=sceneNetSounds)] (@shared_comp net_sound__descs : Object)
    if is_valid(get_desc(name, net_sound__descs, false))
      ++numSounds
      if numSounds == 1
        let connections = target_entity_conn(target)
        if !need_connections || !empty(connections)
          send_net_event(target, CmdPlaySceneNetSound(hash = sound_hash(name), time = get_sync_time()), connections)
  if numSounds > 1
    sound_debug("net_sound: more than one sound with name '{name}' found")
  elif numSounds == 0
    sound_debug("net_sound: sound with name '{name}' not found")


def broadcast_scene_net_sound(name : string;
                              pos : float3;
                              only_for_team_id = TEAM_UNASSIGNED;
                              only_for_squad_eid = INVALID_ENTITY_ID;
                              except_possessed = INVALID_ENTITY_ID;
                              need_connections = false)
  var numSounds = 0
  query() <| $ [es(REQUIRE=sceneNetSounds)] (eid : EntityId; @shared_comp net_sound__descs : Object)
    let desc = get_desc(name, net_sound__descs, false)
    if is_valid(desc)
      ++numSounds
      if numSounds == 1
        let maxRange : float = *desc |> get_float("range") ?? 100.
        let connections = enum_connections_near_pos(pos, maxRange, only_for_team_id, only_for_squad_eid, except_possessed)
        if !need_connections || !empty(connections)
          send_net_event(eid, CmdPlayNetSoundPos(hash = sound_hash(name), pos = pos, time = get_sync_time()), connections)
  if numSounds > 1
    sound_debug("net_sound: more than one sound with name '{name}' found")
  elif numSounds == 0
    sound_debug("net_sound: sound with name '{name}' not found")
