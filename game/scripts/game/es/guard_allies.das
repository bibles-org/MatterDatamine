require ecs
require ecs.common
require app
require math.random
require DagorMath
require Grid


[es(tag=server, on_appear)]
def guard_allies_init(evt : Event;
                      bot_allies__updateInterval : float;
                      var bot_allies__updateAt : float&)
  bot_allies__updateAt = get_sync_time() + gfrnd() *  bot_allies__updateInterval


[es(tag=server, no_order)]
def guard_allies_update(upd : UpdateStageInfoAct;
                        eid aka hero_eid : EntityId;
                        bot_allies__updateInterval : float;
                        bot_allies__radius : float;
                        transform aka hero_transform : float3x4;
                        team aka hero_team : int;
                        var bot_allies__eids : EidList;
                        var bot_allies__closest : EntityId&;
                        var bot_allies__updateAt : float&)
  if upd.curTime < bot_allies__updateAt
    return

  bot_allies__updateAt = upd.curTime + bot_allies__updateInterval

  var closestDistSq = VERY_BIG_NUMBER
  clear(bot_allies__eids)
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(hero_transform[3], bot_allies__radius), GridEntCheck.BOUNDING) <| $(other_eid : EntityId; pos : float3)
    if other_eid == hero_eid
      return
    query(other_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (team aka other_team : int)
      if hero_team != other_team
        return
      let curDistSq = distance_sq(hero_transform[3], pos)
      if closestDistSq < curDistSq
        closestDistSq = curDistSq
        bot_allies__closest = other_eid
      push(bot_allies__eids, other_eid)
