require game.events.events_game
require ecs
require DngDm
require game.events.events_game


[es]
def process_entity_died_by_player(evt : EventAnyEntityDied)
  var offenderPlayer : EntityId = evt.offenderPlayer
  if offenderPlayer == INVALID_ENTITY_ID
    offenderPlayer = get_Eid(evt.offender, "possessedByPlr") ?? INVALID_ENTITY_ID
  var victimPlayer : EntityId = evt.victimPlayer
  if victimPlayer == INVALID_ENTITY_ID
    victimPlayer = get_Eid(evt.victim, "possessedByPlr") ?? INVALID_ENTITY_ID
  if offenderPlayer != INVALID_ENTITY_ID && !empty(getEntityTemplateName(offenderPlayer))
    sendEvent(offenderPlayer, EventPlayerKilledEntity(
                                victimEid = evt.victim,
                                killerEid = evt.offender,
                                deathDesc_gunPropsId = int16(evt.gunPropsId),
                                deathDesc_collNodeId = int16(evt.collNodeId),
                                deathDesc_damageTypeId = uint16(uint(evt.damageType)),
                                victimPlayerEid = victimPlayer,
                                killerPlayerEid = offenderPlayer))// update kills before (potential) send of EventPlayerPlace

  if victimPlayer != INVALID_ENTITY_ID && !empty(getEntityTemplateName(victimPlayer))
    sendEvent(victimPlayer, EventPlayerPossessedEntityDied(
                              victimEid = evt.victim,
                              killerEid = evt.offender,
                              deathDesc_damageTypeId = uint16(uint(evt.damageType)),
                              victimPlayerEid = victimPlayer,
                              killerPlayerEid = offenderPlayer))
