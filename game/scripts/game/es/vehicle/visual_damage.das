require ecs
require ecs.safe
require vehicle
require dm
require DngDm
require AnimV20
require game.events.vehicle_events
require game.events.events_game
require game.events.events_active_matter

[es(tag=server, on_appear)]
def damage_model_part_alive_update_es_event_handler(evt : Event;
                                                    damage_model : DamageModel;
                                                    var damage_part_alive : BoolList)
  let partsCount = get_damage_part_props_count(damage_model.dmData)
  resize(damage_part_alive, partsCount)
  for i in range(0, partsCount)
    damage_part_alive[i] = false

[es(tag=server, no_order)]
def damage_model_part_alive_update_es(act : ParallelUpdateFrameDelayed;
                                      damage_model : DamageModel;
                                      var damage_part_alive : BoolList)
  let partsCount = get_damage_part_props_count(damage_model.dmData)
  for i in range(0, partsCount)
    damage_part_alive[i] = int(get_damage_part_props(damage_model.dmData, i).relHpFixed) > 0

def show_dmg(show : bool;
             coll_node_id : int;
             collNodeIdToNodeIdMain, collNodeIdToNodeIdDmg : IntList;
             var dmg_animchar : DmgAnimChar&;
             var animchar_render : AnimcharRendComponent&)
  if collNodeIdToNodeIdMain[coll_node_id] >= 0 && collNodeIdToNodeIdDmg[coll_node_id] >= 0
    animchar_render.sceneInstance |> scene_instance_show_node(collNodeIdToNodeIdMain[coll_node_id], !show)
    dmg_animchar.sceneInstance |> scene_instance_show_node(collNodeIdToNodeIdDmg[coll_node_id], show)
    return true
  return false

[es(tag=render, track=damage_part_alive, before=before_animchar_update_sync)]
def visual_damage_immediate_es(evt : Event;
                               eid : EntityId;
                               visual_dmg_remap__collNodeIdToNodeIdMain, visual_dmg_remap__collNodeIdToNodeIdDmg : IntList;
                               damage_model : DamageModel;
                               damage_part_alive : BoolList;
                               var animchar_render : AnimcharRendComponent&;
                               var dmg_animchar : DmgAnimChar&;
                               var dmg_animchar__renderable : bool&)
  dmg_animchar__renderable = false
  let damagePartsCount = length(damage_part_alive)
  for i in range(0, damagePartsCount)
    let collNodeId = damage_model.dmData |> get_collision_node_id(i)
    if collNodeId < 0
      continue
    let showDamage = !damage_part_alive[i]
    show_dmg(showDamage, collNodeId, visual_dmg_remap__collNodeIdToNodeIdMain,
             visual_dmg_remap__collNodeIdToNodeIdDmg, dmg_animchar, animchar_render)
    dmg_animchar__renderable ||= showDamage
  sendEvent(eid, NodesVisibilityWasUpdated())

[es(REQUIRE_NOT=(disableUpdate, damage_part_alive, animchar__actOnDemand))]
def visual_damage_es_event_handler(evt : EventOnCollisionHit;
                                   eid : EntityId;
                                   visual_dmg_remap__collNodeIdToNodeIdMain, visual_dmg_remap__collNodeIdToNodeIdDmg : IntList;
                                   damage_model : DamageModel;
                                   var animchar_render : AnimcharRendComponent&;
                                   var dmg_animchar : DmgAnimChar&;
                                   var dmg_animchar__renderable : bool&)
  let collNodeId = evt.collNodeId
  let partId = get_part_id_by_coll_node_id(damage_model.dmData, int(collNodeId))
  if partId < 0 && show_dmg(true, collNodeId, visual_dmg_remap__collNodeIdToNodeIdMain,
                            visual_dmg_remap__collNodeIdToNodeIdDmg, dmg_animchar, animchar_render)
    dmg_animchar__renderable = true
    sendEvent(eid, NodesVisibilityWasUpdated())

[es(REQUIRE_NOT=(disableUpdate, damage_part_alive, animchar__actOnDemand))]
def visual_damage_part_damaged(evt : EventOnPartDamaged;
                               eid : EntityId;
                               visual_dmg_remap__collNodeIdToNodeIdMain, visual_dmg_remap__collNodeIdToNodeIdDmg : IntList;
                               damage_model : DamageModel;
                               var animchar_render : AnimcharRendComponent&;
                               var dmg_animchar : DmgAnimChar&;
                               var dmg_animchar__renderable : bool&)
  let hpFixed = evt.hpFixed
  let collNodeId = damage_model.dmData |> get_collision_node_id(evt.partId)
  if int(hpFixed) == 0 && show_dmg(true, collNodeId, visual_dmg_remap__collNodeIdToNodeIdMain,
                                   visual_dmg_remap__collNodeIdToNodeIdDmg, dmg_animchar, animchar_render)
    dmg_animchar__renderable = true
    sendEvent(eid, NodesVisibilityWasUpdated())

[es(REQUIRE_NOT=(disableUpdate, damage_part_alive, animchar__actOnDemand))]
def visual_damage_on_volumetric_damage(evt : EventOnVolumetricDamage;
                                       eid : EntityId;
                                       visual_dmg_remap__collNodeIdToNodeIdMain, visual_dmg_remap__collNodeIdToNodeIdDmg : IntList;
                                       damage_model : DamageModel;
                                       var animchar_render : AnimcharRendComponent&;
                                       var dmg_animchar : DmgAnimChar&;
                                       var dmg_animchar__renderable : bool&)
  for partIt in evt.damagedParts
    let part = get_ecs_object(partIt)
    let partId = part?.partId ?? -1
    let hpFixed = part?.hpFixed ?? 0
    let collNodeId = damage_model.dmData |> get_collision_node_id(partId)
    if hpFixed == 0 && show_dmg(true, collNodeId, visual_dmg_remap__collNodeIdToNodeIdMain,
                                 visual_dmg_remap__collNodeIdToNodeIdDmg, dmg_animchar, animchar_render)
      dmg_animchar__renderable = true
      sendEvent(eid, NodesVisibilityWasUpdated())
