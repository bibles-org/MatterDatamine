require ecs
require math.base
require math.random
require DagorMath
require Grid
require game.events.events_active_matter
require game.events.events_game
require danetlibs.dm.dm_events


[es(tag=server, on_appear, before=load_beh_tree_es, REQUIRE=area_guard__setOriginOnSpawn)]
def init_guard_area(evt : Event; transform : float3x4; var beh_tree__blackboard__wanderTarget : float3&)
  beh_tree__blackboard__wanderTarget = transform[3]


[es(tag=server, no_order)]
def wake_up_sleeping_guards_on_player_approaches(act : UpdateStageInfoAct;
                                                 eid : EntityId;
                                                 transform aka guard_transform : float3x4;
                                                 sleeping_guard__checkForHumanEnemyRadius : float;
                                                 sleeping_guard__checkForAIEnemyRadius : float;
                                                 sleeping_guard__updateInterval : float;
                                                 var sleeping_guard__updateAt : float&)
  if sleeping_guard__updateAt < act.curTime
    sleeping_guard__updateAt = act.curTime + sleeping_guard__updateInterval + rnd_float(0.0, 0.1) //rnd to ensure they don't all stack on the same frame
    let humanRSq = square(sleeping_guard__checkForHumanEnemyRadius)
    let aiRSq = square(sleeping_guard__checkForAIEnemyRadius)
    let hasPlayersNear = find_query() <| $ [es(REQUIRE=heroForPlayer)] (transform aka hero_transform : float3x4; am_militant_bot : Tag const?)
      return distance_sq(hero_transform[3], guard_transform[3]) < (am_militant_bot != null ? aiRSq : humanRSq)
    if hasPlayersNear
      sendEvent(eid, CmdAwakeSleepingMonster())


[es(tag=server, after=simple_hitpoints_apply_damage, REQUIRE=sleeping_monster, REQUIRE_NOT=deadEntity)]
def awake_guard_on_damaged(evt : CmdApplyDamage;
                           isAlive : bool;
                           transform : float3x4;
                           sleeping_guard__awakeOnHitRadius : float)
  if isAlive
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], sleeping_guard__awakeOnHitRadius), GridEntCheck.POS) <| $(target_eid : EntityId)
      query(target_eid) <| $ [es(REQUIRE=(sleeping_monster, sleeping_guard__awakeOnHitRadius))] (eid : EntityId)
        sendEvent(eid, CmdAwakeSleepingMonster())


[es(on_appear, REQUIRE=sleeping_monster)]
def disable_weapon_updates_on_sleep(evt : Event; human_weap__gunEids : EidList)
  for eid in human_weap__gunEids
    if eid != INVALID_ENTITY_ID
      addSubTemplate(eid, "sleeping_weapon")

[es(on_disappear, REQUIRE=sleeping_monster)]
def enable_weapon_updates_on_unsleep(evt : Event; human_weap__gunEids : EidList)
  for eid in human_weap__gunEids
    if eid != INVALID_ENTITY_ID
      removeSubTemplate(eid, "sleeping_weapon")

[es(on_disappear, REQUIRE=(attachedToParent, sleeping_weapon))]
def unsleep_weapon_on_detached(evt : Event; eid : EntityId)
  removeSubTemplate(eid, "sleeping_weapon")

[es(on_appear, REQUIRE=sleeping_weapon, REQUIRE_NOT=weapon_waiting_for_hero_appear, after=set_weapon_slots_on_appear)]
def unsleep_weapon_on_appear(evt : Event;
                             item__humanOwnerEid : EntityId;
                             eid : EntityId)
  if !has(item__humanOwnerEid, "sleeping_monster")
    removeSubTemplate(eid, "sleeping_weapon")


[es(on_appear, REQUIRE=sleeping_monster)]
def disable_suit_updates_on_sleep(evt : Event; attachable_suit_controller__suitAnimcharEid : EntityId)
  query(attachable_suit_controller__suitAnimcharEid) <| $ [es] (var animchar__updatable : bool&)
    animchar__updatable = false

[es(on_disappear, REQUIRE=sleeping_monster)]
def enable_suit_updates_on_unsleep(evt : Event; attachable_suit_controller__suitAnimcharEid : EntityId)
  query(attachable_suit_controller__suitAnimcharEid) <| $ [es] (var animchar__updatable : bool&)
    animchar__updatable = true