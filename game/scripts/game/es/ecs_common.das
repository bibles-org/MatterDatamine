module ecs_common shared
require ecs
require DagorSystem
require net


def get_entity_info(eid : EntityId) : string
  return "<{eid}> ({getEntityTemplateName(eid)})"


def get_player_info(player_eid : EntityId) : string
  var playerName = "Unknown player"
  var playerPossessed = INVALID_ENTITY_ID
  query(player_eid) <| $ [es] (name : string;
                               possessed aka player_possessed : EntityId;
                               playerIsBot : Tag const?)
    playerName := name

    if playerIsBot != null
      playerName := "{playerName} [BOT]"

    playerPossessed = player_possessed
  return "{get_entity_info(player_eid)} ({playerName}, possessed={playerPossessed})"


def get_player_info_by_possessed(possessed_eid : EntityId) : string
  var playerName = "Unknown player"
  query(possessed_eid) <| $ [es] (possessedByPlr : EntityId)
    playerName := "{get_player_info(possessedByPlr)} (possessed={possessed_eid})"
  return playerName


def ensure_object(var obj : Object;
                  child_name : string;
                  cb : block<(var child : Object) : void>) : bool
  var childValue = getRW_ecs_object(obj, child_name)
  if childValue == null
    using() <| $(var newChildObject : Object)
      obj |> set(child_name, newChildObject)
      childValue = getRW_ecs_object(obj, child_name)

  if childValue != null
    cb |> invoke(*childValue)
    return true
  return false


def ensure_eid(var obj : Object;
               child_name : string;
               default_value : EntityId;
               cb : block<(var child : EntityId&) : void>) : bool
  var childValue = getRW_Eid(obj, child_name)
  if childValue == null
    obj |> set(child_name, default_value)
    childValue = getRW_Eid(obj, child_name)

  if childValue != null
    cb |> invoke(*childValue)
    return true
  return false


def ensure_int(var obj : Object;
               child_name : string;
               default_value : int;
               cb : block<(var child : int&) : void>) : bool
  var childValue = getRW_int(obj, child_name)
  if childValue == null
    obj |> set(child_name, default_value)
    childValue = getRW_int(obj, child_name)

  if childValue != null
    cb |> invoke(*childValue)
    return true
  return false


def ensure_float(var obj : Object;
                 child_name : string;
                 default_value : float;
                 cb : block<(var child : float&) : void>) : bool
  var childValue = getRW_float(obj, child_name)
  if childValue == null
    obj |> set(child_name, default_value)
    childValue = getRW_float(obj, child_name)

  if childValue != null
    cb |> invoke(*childValue)
    return true
  return false


def ensure_float4(var obj : Object;
                  child_name : string;
                  default_value : float4;
                  cb : block<(var child : float4&) : void>) : bool
  var childValue = getRW_Point4(obj, child_name)
  if childValue == null
    obj |> set(child_name, default_value)
    childValue = getRW_Point4(obj, child_name)

  if childValue != null
    cb |> invoke(*childValue)
    return true
  return false


def ensure_string(var obj : Object;
                  child_name : string;
                  default_value : string;
                  cb : block<(var child : das_string) : void>) : bool
  var childValue = getRW_ecs_string(obj, child_name)
  if childValue == null
    obj |> set(child_name, default_value)
    childValue = getRW_ecs_string(obj, child_name)

  if childValue != null
    cb |> invoke(*childValue)
    return true
  return false


// Returns random int in range [0..0x7fffffff] based on eid value
def eid_rnd(eid : EntityId) : int
  var x = uint(eid)
  // Magic consts taken from https://github.com/skeeto/hash-prospector#discovered-hash-functions
  x ^= x >> 16u
  x *= 0x21f0aaadu
  x ^= x >> 15u
  x *= 0xd35a2d97u
  x ^= x >> 15u
  return int(x & 0x7fffffff)


def eid_rnd(eid : EntityId;
            from : int;
            to : int) : int
  return eid_rnd(eid) % (to - from + 1) + from


def get_DESTROY_ENTITY_FLOOR_Y() : float
  return -(512.0 - 100.0)


def get_HIDDEN_QWPOS_XYZ()
  return float3(-(4096 - 1), -(512 - 1), -(4096 - 1))


def validate_gameplay_position(pos : float3;
                               info : string = "")
  if is_nan(pos.x) || is_nan(pos.y) || is_nan(pos.z)
    logerr("Gameplay position is NaN - {pos}! {info}")
    return false

  if !is_server()
    // Client only checks
    if distance_sq(pos, get_HIDDEN_QWPOS_XYZ()) < 1.0
      // Net stash is valid gameplay position on the client
      return true

  if pos.y < get_DESTROY_ENTITY_FLOOR_Y() || pos.y > 2000.0 || abs(pos.x) >= 10000.0 || abs(pos.z) >= 10000.0
    logerr("Gameplay position is invalid - {pos}! {info}")
    return false

  return true

def validate_gameplay_position(pos : float3;
                               msg : block<() : string>)
  if is_nan(pos.x) || is_nan(pos.y) || is_nan(pos.z)
    let info = msg |> invoke()
    logerr("Gameplay position is NaN - {pos}! {info}")
    return false

  if !is_server()
    // Client only checks
    if distance_sq(pos, get_HIDDEN_QWPOS_XYZ()) < 1.0
      // Net stash is valid gameplay position on the client
      return true

  if pos.y < get_DESTROY_ENTITY_FLOOR_Y() || pos.y > 2000.0 || abs(pos.x) >= 10000.0 || abs(pos.z) >= 10000.0
    let info = msg |> invoke()
    logerr("Gameplay position is invalid - {pos}! {info}")
    return false

  return true

def is_entity_archetype_exists(eid : EntityId) : bool
  if eid == INVALID_ENTITY_ID
    return false

  let templateName = getEntityTemplateName(eid)
  return !empty(templateName)


def send_event_if_possible(eid : EntityId;
                           var evt)
  if is_entity_archetype_exists(eid)
    sendEvent(eid, evt)
  elif eid != INVALID_ENTITY_ID && get_DAECS_EXTENSIVE_CHECKS() != 0
    logwarn("Entity <{eid}> have no archetype! (evt={typeinfo stripped_typename(evt)})")


def remove_sub_template_if_possible(eid : EntityId;
                                    template_name : string)
  if is_entity_archetype_exists(eid)
    removeSubTemplate(eid, template_name)
  elif eid != INVALID_ENTITY_ID && get_DAECS_EXTENSIVE_CHECKS() != 0
    logwarn("Entity <{eid}> have no archetype! (template_name={template_name})")