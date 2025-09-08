require ecs
require game.es.confusion_common
require game.events.events_active_matter


[es(tag=server, REQUIRE=game_effect__confusionAffect)]
def do_confusion_affect(evt : ApplyGameAffect)
  enable_confusion_affect(evt.targetEid)
