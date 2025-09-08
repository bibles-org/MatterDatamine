require ecs
require app
require math.base
require math.color
require DagorMath
require Grid
require game.events.events_game
require game.events.events_active_matter
require active_matter.game.es.entity_outline_common
require game.es.ability_common


[es(tag=gameClient, no_order)]
def disable_game_outline(act : ParallelUpdateFrameDelayed; eid, game_effect__attachedTo : EntityId; game_effect_outline__disableAt : float)
  if get_sync_time() > game_effect_outline__disableAt
    query(game_effect__attachedTo) <| $ [es] (var outline__enabled : bool&)
      outline__enabled = false
    destroyEntity(eid)


[es(tag=gameClient, on_appear)]
def on_corpse_start_outline(evt : Event;
                            ragdoll_phys_obj__attachedTo : EntityId;
                            outline_attached_corpse__outlineTemplateName : string)
  if !empty(outline_attached_corpse__outlineTemplateName)
    ragdoll_phys_obj__attachedTo |> addSubTemplate(outline_attached_corpse__outlineTemplateName)


[es(tag=gameClient, on_disappear)]
def on_corpse_stop_outline(evt : Event;
                           ragdoll_phys_obj__attachedTo : EntityId;
                           outline_attached_corpse__outlineTemplateName : string)
  if !empty(outline_attached_corpse__outlineTemplateName)
    ragdoll_phys_obj__attachedTo |> removeSubTemplate(outline_attached_corpse__outlineTemplateName)


[es(tag=gameClient, no_order, REQUIRE=watchedByPlr)]
def update_changed_human_vision(act : ParallelUpdateFrameDelayed;
                                eid : EntityId;
                                transform aka origin_transform : float3x4;
                                changed_human_vision__colorTaken : E3DCOLOR;
                                changed_human_vision__interval : float;
                                changed_human_vision__radius : float;
                                var changed_human_vision__outlinedEids : EidList;
                                var changed_human_vision__updateAt : float&)
  if act.curTime > changed_human_vision__updateAt
    changed_human_vision__updateAt = act.curTime + changed_human_vision__interval

    let sphere = BSphere3(origin_transform[3], changed_human_vision__radius)
    var affectedEids : array<EntityId>
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(target_eid : EntityId)
      query(target_eid) <| $ [
          es(REQUIRE_NOT=deadEntity, REQUIRE=(changed, tamable_creature__behNode))] (minion_creature__masterEid : EntityId const?;
                                                                                     outline__disabledUntil : float = 0.0;
                                                                                     var outline__enabled : bool&;
                                                                                     var outline__color : E3DCOLOR&)
        let isOwned = (minion_creature__masterEid ?? INVALID_ENTITY_ID) == eid
        outline__enabled = isOwned && act.curTime > outline__disabledUntil

        if outline__enabled
          outline__color = changed_human_vision__colorTaken
          affectedEids |> push(target_eid)


    var i = length(changed_human_vision__outlinedEids)
    while i-- > 0
      let idx = find_index(affectedEids, changed_human_vision__outlinedEids[i])
      if idx == -1
        query(changed_human_vision__outlinedEids[i]) <| $ [es] (var outline__enabled : bool&)
          outline__enabled = false
        erase(changed_human_vision__outlinedEids, i)
      else
        affectedEids[idx] = INVALID_ENTITY_ID
    for e in affectedEids
      if e != INVALID_ENTITY_ID
        changed_human_vision__outlinedEids |> push(e)


[es(on_appear)]
def game_effect_disable_outline_on_appear_for_time(evt : Event;
                                                   game_effect__attachedTo : EntityId;
                                                   game_effect__disableOutlineOnAppearForTime : float)
  query(game_effect__attachedTo) <| $ [es] (var outline__disabledUntil : float&)
    outline__disabledUntil = get_sync_time() + game_effect__disableOutlineOnAppearForTime