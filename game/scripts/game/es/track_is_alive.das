require ecs

[es(track=isAlive, on_appear, REQUIRE_NOT=entity__recreateToOnDeath)]
def track_is_alive(evt : Event;
                   eid : EntityId;
                   isAlive : bool;
                   entity__deathTemplate : das_string const?)
  let deathTemplate = entity__deathTemplate != null ? string(*entity__deathTemplate) : "dead_entity"
  if !isAlive
    addSubTemplate(eid, deathTemplate)
  elif has(eid, "deadEntity")
    removeSubTemplate(eid, deathTemplate)