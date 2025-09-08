require ecs
require app
require game.utils.team
require game.events.events_game
require game.events.events_active_matter


[es(tag=server, on_appear)]
def resurrect_initial_template_es(evt : Event;
                                  eid : EntityId;
                                  var resurrect_template : das_string&)
  // take the initial template name, so we can resurrect the same entity with loadouts and stuff
  resurrect_template := getEntityTemplateName(eid)

[es(tag=server)]
def resurrect_monster(evt : EventEntityDied;
                      isAlive : bool;
                      resurrect_after_death__timeToResurrect : float;
                      resurrect_template : string;
                      beh_tree__enabled : bool;
                      transform : float3x4)
  if isAlive
    return
  createEntity("resurrect_timer") <| $(var init)
    set(init, "transform", transform)
    set(init, "resurrect_timer__resurrectAt", get_sync_time() + resurrect_after_death__timeToResurrect)
    set(init, "beh_tree__enabled", beh_tree__enabled)
    set(init, "resurrect_timer__templateToResurrect", resurrect_template)


[es(tag=server, no_order)]
def countdown_to_resurrection(info : ParallelUpdateFrameDelayed;
                              eid : EntityId;
                              resurrect_timer__templateToResurrect : string;
                              transform : float3x4;
                              beh_tree__enabled : bool;
                              resurrect_timer__resurrectAt : float)
  if info.curTime >= resurrect_timer__resurrectAt
    createEntity(resurrect_timer__templateToResurrect) <| $(var init)
      set(init, "transform", transform)
      set(init, "beh_tree__enabled", beh_tree__enabled)
    destroyEntity(eid)


