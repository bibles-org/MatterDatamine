module concussion_common shared
require ecs
require ecs.common


def private disable_concussion_affect_impl(owner_eid : EntityId; replaced : bool)
  find_query() <| $ [es(REQUIRE=concussionAffect)] (eid : EntityId; game_effect__attachedTo : EntityId; var concussion__replaced : bool&)
    if game_effect__attachedTo != owner_eid
      return false
    concussion__replaced = replaced
    destroyEntity(eid)
    return true

def disable_concussion_affect(owner_eid : EntityId)
  disable_concussion_affect_impl(owner_eid, false)

def replace_concussion_affect(owner_eid : EntityId)
  disable_concussion_affect_impl(owner_eid, true)

def enable_concussion_affect(owner_eid : EntityId; concussion_template : string)
  replace_concussion_affect(owner_eid)
  createEntity(concussion_template) <| $(var init : ComponentsInitializer)
    set(init, "game_effect__attachedTo", owner_eid)

def has_concussion_affect(owner_eid : EntityId) : bool
  return find_query() <| $ [es(REQUIRE=concussionAffect)] (game_effect__attachedTo : EntityId)
    return game_effect__attachedTo == owner_eid