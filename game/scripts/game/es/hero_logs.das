require ecs
require ecs.safe
require game.es.ecs_common
require game.events.events_game
require DngDm


def get_actor_additional_info(actor_eid : EntityId)
  var info : string
  query(actor_eid) <| $ [es] (transform : float3x4)
    info = "{info}\ttransform={transform}\n"

  return <- info


def print_hero_died_logs(evt : EventEntityDied;
                         human_damage_model__parts : Object const?)
  var hitpointsText : string
  if human_damage_model__parts != null
    for slotData in *human_damage_model__parts
      let key = slotData.key
      let value = slotData.value as Object

      hitpointsText = "{hitpointsText}\t{key} hp:{value?.hp ?? 0.0}/{value?.maxHp ?? 0.0}\n"

  print("[HERO] [DEATH]:
victim={get_entity_info(evt.victim)}
victim_info:\n{get_actor_additional_info(evt.victim)}
offender={get_entity_info(evt.offender)}
offender_info:\n{get_actor_additional_info(evt.offender)}
damageType={DamageType(int(evt.damageType))}
gunPropsId={evt.gunPropsId}
shellId={evt.shellId}
collNodeId={evt.collNodeId}
victimTeam={evt.victimTeam}
offenderTeam={evt.offenderTeam}
hitpoints:\n{hitpointsText}")


[es(tag=server, REQUIRE=heroForPlayer)]
def hero_died_server(evt : EventEntityDied;
                     human_damage_model__parts : Object const?)
  print_hero_died_logs(evt, human_damage_model__parts)


[es(tag=netClient, REQUIRE=hero)]
def hero_died_client(evt : EventEntityDied;
                     human_damage_model__parts : Object const?)
  print_hero_died_logs(evt, human_damage_model__parts)
