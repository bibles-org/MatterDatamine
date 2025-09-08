require ecs
require DngDm
require game.events.events_active_matter
require DagorMath


[es(tag=server, REQUIRE=game_effect__suicide)]
def do_suicide_affect(evt : ApplyGameAffect)
  query(evt.targetEid) <| $ [es] (transform : float3x4)
    let damageDesc = DamageDesc(DamageType.DM_UNKNOWN, VERY_BIG_NUMBER, transform[3])
    damage_entity(evt.targetEid, evt.targetEid, damageDesc)