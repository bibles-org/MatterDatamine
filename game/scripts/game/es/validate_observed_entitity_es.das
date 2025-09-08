require ecs

/*
  currently there can be more than one observed entity - it happens when controlled hero dies but entity still exists
  this is workaround
  however better would be to set watchedByPlr ONLY by specTarget, watchedByPlr should be only calculated from specTarget
*/


def validate_observed_entity(valid_target : EntityId)
  if valid_target == INVALID_ENTITY_ID
    return
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid : EntityId)
    if eid != valid_target
      debug("[Validate observed entity] clearing incorrect obervables. target {valid_target} incorrect observed eid: {eid}")
      removeSubTemplate(eid, "spectator_observed")


[es(tag=gameClient, on_appear, track=(possessed, specTarget, is_local), REQUIRE=player)]
def validate_observed_entity_es(evt : Event;
                                possessed : EntityId;
                                specTarget : EntityId;
                                is_local : bool)
  if is_local
    var isPossessedAlive = false
    query(possessed) <| $ [es] (isAlive : bool)
      isPossessedAlive = isAlive
    if isPossessedAlive
      validate_observed_entity(possessed)
    elif specTarget != INVALID_ENTITY_ID
      validate_observed_entity(specTarget)
