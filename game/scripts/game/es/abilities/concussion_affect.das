require ecs
require game.es.concussion_common
require game.events.events_active_matter


[es(tag=server, REQUIRE=game_effect__concussionAffect)]
def do_concussion_affect(evt : ApplyGameAffect; game_effect__customConcussionTemplate : string = "")
  if game_effect__customConcussionTemplate != ""
    enable_concussion_affect(evt.targetEid, game_effect__customConcussionTemplate)
  else
    query(evt.targetEid) <| $ [es] (concussion__template : string)
      enable_concussion_affect(evt.targetEid, concussion__template)

