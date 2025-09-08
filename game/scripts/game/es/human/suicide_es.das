require ecs
require game.events.events
require DngDm

[es(on_event=RequestSuicide, tag=server, REQUIRE=hitpoints)]
def human_suicide_es(evt : Event; eid : EntityId)
  sendEvent(eid, CmdKill(damageType = uint16(int(DamageType.DM_MELEE)), deathHpDamage = 100.0))
