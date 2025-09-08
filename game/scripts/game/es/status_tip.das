require ecs
require game.es.status_tip_common
require game.events.events_active_matter


[es(tag=gameClient, REQUIRE=hero)]
def show_status_tip_from_server(evt : ShowStatusTip)
  create_status_tip(evt.statusTip)
