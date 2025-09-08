module keys_and_locks_common shared
require ecs
require Grid
require DngNet
require math.base
require DagorMath


def try_mark_doors_closed(tm : float3x4; locked_template : string; tag_list : StringList)
  var list : array<EntityId>
  let bbox = tm * BBox3(float3(), 1.0)
  for_each_entity_in_grid(ecs_hash("doors"), bbox, GridEntCheck.POS) <| $(doorEid : EntityId)
    query(doorEid) <| $ [es(REQUIRE_NOT=looked_door__template)] (isDoor : bool;
                                                                 pair_door__eid : EntityId;
                                                                 transform : float3x4;
                                                                 door_operations__closedAngle : float;
                                                                 var door_operations__serverTargetAngle : float&)
      if isDoor && is_inside_tm(transform[3], tm)
        if !has_value(list, doorEid)
          list |> push(doorEid)
          door_operations__serverTargetAngle = door_operations__closedAngle
        if pair_door__eid != INVALID_ENTITY_ID && !has_value(list, pair_door__eid)
          list |> push(pair_door__eid)
          query(pair_door__eid) <| $ [es] (door_operations__closedAngle : float;
                                           var door_operations__serverTargetAngle : float&)
            door_operations__serverTargetAngle = door_operations__closedAngle
  for d in list
    remote_add_sub_template(d, locked_template) <| $(init)
      init |> set("locked__keyTags", tag_list)
      init |> set("looked_door__template", locked_template)


def have_same_tag(first_tags_array, second_tags_array : StringList) : bool
  for first_tag in first_tags_array
    for second_tag in second_tags_array
      if first_tag == second_tag
        return true
  return false
