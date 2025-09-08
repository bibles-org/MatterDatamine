require ecs


[es(on_appear)]
def agent_switchable_collision_init(evt : Event;
                                    eid : EntityId;
                                    agent_switchable_collision__collisionEnabled : bool;
                                    agent_switchable_collision__collisionTemplate : string)
  if agent_switchable_collision__collisionEnabled
    addSubTemplate(eid, agent_switchable_collision__collisionTemplate)


[es(track=agent_switchable_collision__collisionEnabled)]
def agent_switchable_collision_track_enabled(evt : Event;
                                             eid : EntityId;
                                             agent_switchable_collision__collisionEnabled : bool;
                                             agent_switchable_collision__collisionTemplate : string)
  if agent_switchable_collision__collisionEnabled
    addSubTemplate(eid, agent_switchable_collision__collisionTemplate)
  else
    removeSubTemplate(eid, agent_switchable_collision__collisionTemplate)


[es(track=isAlive)]
def agent_switchable_collision_dead(evt : Event;
                                    isAlive : bool;
                                    agent_switchable_collision__disableOnDeath : bool = true;
                                    var agent_switchable_collision__collisionEnabled : bool&)
  if !isAlive && agent_switchable_collision__disableOnDeath
    agent_switchable_collision__collisionEnabled = false