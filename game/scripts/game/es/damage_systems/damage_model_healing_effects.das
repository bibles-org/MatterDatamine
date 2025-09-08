require app
require ecs
require DngNet
require DngHuman
require DagorSystem
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.damage_systems.damage_model_common
require game.es.entity_mods_common
require game.utils.net_utils


[es(tag=server, on_appear)]
def instant_healing_bodypart_effect(evt : Event;
                                    game_effect__attachedTo : EntityId;
                                    healing_effect__bodypartIdx : int;
                                    healing_effect__healAmount : float)
  query(game_effect__attachedTo) <| $ [es] (entity_mod_values : Object; var human_damage_model__parts : Object)
    for part, idx in human_damage_model__parts, iter_range(human_damage_model__parts)
      if idx != healing_effect__bodypartIdx
        continue
      let obj = get_ecs_object(part.value)
      if obj == null
        continue
      let p = make_object_of_body_part(*obj)
      let healAmount = healing_effect__healAmount * get_mod_value("healingMult", entity_mod_values, 1.0)
      human_damage_model_add_part_hp(game_effect__attachedTo, p.name, healAmount)
      break


[es(tag=server, on_appear)]
def healing_of_time_effect_appear(evt : Event;
                                  eid aka my_eid : EntityId;
                                  game_effect__attachedTo aka my_game_effect__attachedTo : EntityId;
                                  healing_effect__healTick : float;
                                  healing_effect__healTicksCount aka my_healing_effect__healTicksCount : int;
                                  var healing_effect__nextHealAt : float&)
  let alreadyHasEffect = find_query() <| $ [es] (eid : EntityId;
                                                 game_effect__attachedTo : EntityId;
                                                 var healing_effect__healTicksCount : int&)
    if my_game_effect__attachedTo == game_effect__attachedTo && my_eid != eid
      healing_effect__healTicksCount = my_healing_effect__healTicksCount
      return true
    return false
  let curTime = get_sync_time()
  if alreadyHasEffect
    destroyEntity(eid)
  else
    healing_effect__nextHealAt = curTime + healing_effect__healTick
  let effectEnds = curTime + float(my_healing_effect__healTicksCount) * healing_effect__healTick
  send_net_event(game_effect__attachedTo, CmdShowHealOverTimeEffect(begin = curTime, end = effectEnds), possessed_and_spectated(my_game_effect__attachedTo))


[es(tag=server, on_appear)]
def healing_stream_effect_appear(evt : Event;
                                 eid : EntityId;
                                 healing_effect__healItem : EntityId;
                                 var healing_effect__nextHealAt : float&;
                                 var healing_effect__healTick : float&;
                                 var healing_effect__healByTickAmount : float&)
  query(healing_effect__healItem) <| $ [es] (item__amount : int;
                                             item_heal__healTick : float;
                                             item_heal__healPerTick : float;
                                             var item_heal__healEffect : EntityId&)
    healing_effect__healTick = item_heal__healTick
    healing_effect__healByTickAmount = min(float(item__amount), item_heal__healPerTick)
    item_heal__healEffect = eid
  healing_effect__nextHealAt = get_sync_time() + healing_effect__healTick


[es(tag=server)]
def healing_effect_heal(act : ParallelUpdateFrameDelayed;
                        game_effect__attachedTo : EntityId;
                        healing_effect__healByTickAmount : float;
                        healing_effect__nextHealAt : float;
                        var healing_effect__healedByCurrentTickAmount : float?)
  if act.curTime < healing_effect__nextHealAt
    return
  query(game_effect__attachedTo) <| $ [es] (isAlive : bool; entity_mod_values : Object; human_damage_model__parts : Object)
    if !isAlive
      return
    var worstBodypartName = ""
    var worstBodypartMissingHp = 0.0
    var worstBodypartHpRel = 1.0
    for_each_part_in_damage_model(human_damage_model__parts) <| $(bodypart : BodyPartV2)
      let bodypartHpRel = bodypart.hp / bodypart.maxHp
      if bodypartHpRel <= worstBodypartHpRel
        worstBodypartName = bodypart.name
        worstBodypartMissingHp = bodypart.maxHp - bodypart.hp
        worstBodypartHpRel = bodypartHpRel
      return true
    if !empty(worstBodypartName)

      let healAmount = min(worstBodypartMissingHp, healing_effect__healByTickAmount * get_mod_value("healingMult", entity_mod_values, 1.0))
      if healing_effect__healedByCurrentTickAmount != null
        *healing_effect__healedByCurrentTickAmount = healAmount
      human_damage_model_add_part_hp(game_effect__attachedTo, worstBodypartName, healAmount)


[es(tag=server, after=healing_effect_heal, before=healing_effect_timer_update)]
def healing_of_time_effect_end(act : ParallelUpdateFrameDelayed;
                               eid : EntityId;
                               healing_effect__nextHealAt : float;
                               var healing_effect__healTicksCount : int&)
  if act.curTime < healing_effect__nextHealAt
    return
  healing_effect__healTicksCount -= 1
  if healing_effect__healTicksCount <= 0
    destroyEntity(eid)


[es(tag=server, after=healing_effect_heal, before=healing_effect_timer_update)]
def healing_stream_effect_end(act : ParallelUpdateFrameDelayed;
                              eid : EntityId;
                              game_effect__attachedTo : EntityId;
                              healing_effect__healItem : EntityId;
                              healing_effect__nextHealAt : float;
                              healing_effect__healedByCurrentTickAmount : float;
                              var healing_effect__healByTickAmount : float&)
  if act.curTime < healing_effect__nextHealAt
    return
  var shouldDestroy = false
  query(healing_effect__healItem) <| $ [es] (var item__amount : int&)
    item__amount -= int(healing_effect__healedByCurrentTickAmount)
    healing_effect__healByTickAmount = min(float(item__amount), healing_effect__healByTickAmount)
    shouldDestroy ||= item__amount <= 0
  query(game_effect__attachedTo) <| $ [es] (human_damage_model__parts : Object)
    shouldDestroy ||= get_damaged_parts_count(human_damage_model__parts) == 0
  if shouldDestroy
    sendEvent(game_effect__attachedTo, EventInterruptItemUse())
    destroyEntity(eid)
    return


[es(no_order)]
def healing_effect_timer_update(act : ParallelUpdateFrameDelayed;
                                healing_effect__healTick : float;
                                var healing_effect__nextHealAt : float&)
  if act.curTime < healing_effect__nextHealAt
    return
  healing_effect__nextHealAt += healing_effect__healTick


[es(tag=server, no_order)]
def damage_model_regeneration_act_server(act : UpdateStageInfoAct;
                                         eid : EntityId;
                                         human_damage_model__parts : Object;
                                         isAlive : bool;
                                         damage_model_regeneration__healTick : float;
                                         damage_model_regeneration__healByTickAmount : float;
                                         var damage_model_regeneration__nextHealAt : float&)
  if !isAlive || act.curTime < damage_model_regeneration__nextHealAt
    return
  damage_model_regeneration__nextHealAt += damage_model_regeneration__healTick

  var worstBodypartName = ""
  var worstBodypartHpRel = 1.0
  for_each_part_in_damage_model(human_damage_model__parts) <| $(bodypart : BodyPartV2)
    let bodypartHpRel = bodypart.hp / bodypart.maxHp
    if bodypartHpRel <= worstBodypartHpRel
      worstBodypartName = bodypart.name
      worstBodypartHpRel = bodypartHpRel
    return true
  if !empty(worstBodypartName)
    let healAmount = damage_model_regeneration__healByTickAmount
    human_damage_model_add_part_hp(eid, worstBodypartName, healAmount)
