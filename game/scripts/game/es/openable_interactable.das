require ecs
require ecs.common
require app
require level
require game.events.events
require game.events.events_active_matter
require game.es.riextra_common
require RendInst
require DngNet


[es(tag=server, REQUIRE=openable_external_inventory_container_ri)]
def on_openable_interactable_open_action(evt : EventExternalInventoryAccesspointAccessed;
                                         var openable_ri__isOpened : bool&)
  openable_ri__isOpened = true


[es(tag=server, track=openable_ri__isOpened)]
def openable_interactable_ri_track_opened(evt : Event;
                                          eid : EntityId;
                                          openable_ri__isOpened : bool;
                                          ri_preload__name : string;
                                          openable_ri__closed : string = "")
  if openable_ri__isOpened
    if ri_preload__name != ""
      send_net_event(eid, CmdReplaceRiExtraRes(
        riExtra := ri_preload__name,
        destroyPrevRi = true,
        addPrevRiToRestorables = true,
        createPrevRiDestr = false))
  else
    if openable_ri__closed != ""
      send_net_event(eid, CmdReplaceRiExtraRes(
          riExtra := openable_ri__closed,
          destroyPrevRi = true,
          addPrevRiToRestorables = true,
          createPrevRiDestr = false))

