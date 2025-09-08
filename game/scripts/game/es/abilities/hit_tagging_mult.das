require ecs

def get_new_mult(owner, cur_eid : EntityId)
  var count = 0
  var summ = 0.0
  ecs::query() <| $ [es] (eid, game_effect__attachedTo : EntityId; hitTaggingMult : float)
    if game_effect__attachedTo == owner && cur_eid != eid
      summ += hitTaggingMult
      count++
  return count != 0 ? summ / float(count) : 1.0

[es(tag=server, on_appear, track=game_effect__attachedTo, REQUIRE=hitTaggingMult)]
def hit_tagging_mult_set_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_hit_tagging__mult : float&)
    let newMult = get_new_mult(game_effect__attachedTo, INVALID_ENTITY_ID)
    human_hit_tagging__mult = newMult

[es(tag=server, on_disappear, REQUIRE=hitTaggingMult)]
def hit_tagging_mult_unset_es(evt : Event; game_effect__attachedTo, eid : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_hit_tagging__mult : float&)
    let newMult = get_new_mult(game_effect__attachedTo, eid)
    human_hit_tagging__mult = newMult

