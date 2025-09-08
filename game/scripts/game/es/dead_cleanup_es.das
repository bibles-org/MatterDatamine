require ecs
require game.events.events
require game.events.events_game
require Grid
require DagorMath


[es(tag=server, no_order, REQUIRE_NOT=dontBodyCleanupOnDeath)]
def dead_cleanup_es(evt : EventEntityDied;
                    eid : EntityId;
                    bodyCleanupTime : float)
  sendEvent(eid, CmdBodyCleanup(time = bodyCleanupTime))

[es(tag=server, on_disappear)]
def remove_possessed_on_dissapear_corpse(evt : Event; eid, possessedByPlr : EntityId)
  query(possessedByPlr) <| $ [es] (var possessed : EntityId&)
    if possessed == eid
      possessed = INVALID_ENTITY_ID


[es(tag=server, before=bodies_cleanup_es)]
def prolong_body_cleanup_ttl_for_lootable_monsters(info : UpdateStageInfoAct;
                                                   bodies_cleanup__prolongLootableMonstersTtlInRad : float;
                                                   bodies_cleanup__prolongDelay : float;
                                                   var bodies_cleanup__prolongAt : float&)
  if info.curTime < bodies_cleanup__prolongAt
    return
  bodies_cleanup__prolongAt = info.curTime + bodies_cleanup__prolongDelay

  query() <| $ [es] (am_pile_attached_to_corpse__corpseEid : EntityId;
                     transform : float3x4)
    query(am_pile_attached_to_corpse__corpseEid) <| $ [es] (ragdoll_phys_obj__attachedTo : EntityId)
      query(ragdoll_phys_obj__attachedTo) <| $ [es] (bodyCleanupTime : float)
        let sphere = BSphere3(transform[3], bodies_cleanup__prolongLootableMonstersTtlInRad)
        for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(hero_eid : EntityId)
          query(hero_eid) <| $ [es(REQUIRE_NOT=(deadEntity, am_militant_bot), REQUIRE=heroForPlayer)] ()
            sendEventImmediate(ragdoll_phys_obj__attachedTo, CmdBodyCleanupUpdateTtl(time = bodyCleanupTime))