module diy_ability_common shared

require ecs
require Grid
require DagorMath
require CollRes
require Dacoll
require DngNet

let DIY_ABILITY_NAME = "diy"


def get_human_preview_eid(hero_eid : EntityId)
  var previewEid = INVALID_ENTITY_ID
  find_query() <| $ [es] (game_effect__attachedTo : EntityId; diy__previewControllerEid : EntityId)
    if game_effect__attachedTo == hero_eid
      previewEid = diy__previewControllerEid
    return game_effect__attachedTo == hero_eid

  if previewEid == INVALID_ENTITY_ID
    find_query() <| $ [es] (game_effect__attachedTo : EntityId; diy__previewEid : EntityId)
      if game_effect__attachedTo == hero_eid
        previewEid = diy__previewEid
      return game_effect__attachedTo == hero_eid

  return previewEid


def is_diy_conflict_with_objects_in_grid(tm : float3x4; radius : float) : bool
  var testRadius = radius

  if !is_server()
    // Additional empirical offset on the client side to avoid the difference
    // between the client and server hero positions
    testRadius += 0.3

  let sphere = BSphere3(tm[3], testRadius)

  return is_entity_found_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("vehicles")), sphere, GridEntCheck.POS)


def is_diy_conflict_with_world(tm : float3x4; collobj : CollisionObject; base_collres : CollisionResource const?)
  let boundingSphereRadius = base_collres != null ? (*base_collres).boundingSphereRad : 1f
  dacoll_set_collision_object_tm(collobj, tm)
  let testResult = is_diy_conflict_with_objects_in_grid(tm, boundingSphereRadius) || test_collision_world(collobj, tm, boundingSphereRadius)
  // temporarily hiding under the ground
  var stashTm = tm
  stashTm[3].y = -100000f
  dacoll_set_collision_object_tm(collobj, stashTm)
  return testResult


def is_diy_visible(diy_pos, hero_pos : float3)
  let tracePos = hero_pos
  let traceDir = normalize(diy_pos - hero_pos)
  let len = length(diy_pos - hero_pos)
  return !rayhit_normalized(tracePos, traceDir, len, ETF_DEFAULT, -1)


def test_diy_available_stand(tm : float3x4)
  var fail = false
  let sphere = BSphere3(tm[3], 0.1f)
  for_each_entity_in_grid(ecs_hash("diy"), sphere, GridEntCheck.BOUNDING) <| $ [unused_argument(eid)] (eid : EntityId)
    fail = true
  if fail
    return !fail
  var len = 1f
  var norm : float3
  var pmid : int
  var riDesc = RendInstDesc()
  let tracePos = tm[3]
  let traceDir = -tm[1]
  if traceray_normalized(tracePos, traceDir, len, pmid, norm, ETF_DEFAULT, riDesc, -1)
    let riEid = find_ri_extra_eid(riDesc.riExtraHandle)
    query(riEid) <| $ [es] (isDoor : bool const?;
                            set_rotation : Tag const?;
                            diy_stand_disabled : Tag const?)
      fail ||= isDoor != null || set_rotation != null || diy_stand_disabled != null
  return !fail