require ecs
require ecs.common
require ecs.safe
require game.events.events
require math
require math.base
require CapsuleApproximation
require game.es.node_attach_common
require game.es.render.effect_animation_common
require DagorSystem
require DagorMath
require GeomNodeTree
require AnimV20
require strings


def destroy_assigned_zone_decays(human_eid : EntityId)
  query() <| $ [es(REQUIRE=zone_decay)] (eid : EntityId; node_attached__entity : EntityId)
    if node_attached__entity == human_eid
      destroyEntity(eid)


[es(on_appear, track=(isAlive, inStormZone), tag=render, before=effect_animation_update_es)]
def zone_decay_effects_state_es(evt : Event; eid aka human_eid : EntityId;
                                animchar : AnimcharBaseComponent;
                                zone_decay__pillarEffectTemplate : string;
                                isAlive = true;
                                inStormZone : bool)
  if (inStormZone && isAlive && !empty(zone_decay__pillarEffectTemplate)) // start decay
    let decayEffectEid = createEntity(zone_decay__pillarEffectTemplate) <| $(var init : ComponentsInitializer)
      var nodeTm : float3x4
      geomtree_getNodeWtmScalar(*animchar.nodeTree, 0, nodeTm)
      var tm = IDENT_TM
      tm[3] = nodeTm[3]
      set(init, "transform", tm)

    attach_to_node_pos(decayEffectEid, eid, 0, float3())
  else // end decay
    destroy_assigned_zone_decays(human_eid)


[es(on_disappear, tag=render, before=effect_animation_update_es, REQUIRE=zone_decay__effectTemplate)]
def zone_decay_effects_destroy(evt : Event; eid : EntityId)
  destroy_assigned_zone_decays(eid)
