require ecs
require game.es.spawn_common
require game.events.events_active_matter

def disable_ui()
  let entity = getSingletonEntity("ui_disabled")
  if entity == INVALID_ENTITY_ID
    createEntity("ui_disabled") <| $ [es] (var init : ComponentsInitializer)
      init |> set("ui__disabled", true)

def enable_ui()
  let entity = getSingletonEntity("ui_disabled")
  if entity != INVALID_ENTITY_ID
    destroyEntity(entity)

[es(tag=gameClient, track=level_is_loading, on_appear)]
def disable_ui_on_level_is_loading(evt : Event; level_is_loading : bool)
  if level_is_loading
    disable_ui()

[es(tag=gameClient, REQUIRE=eid)]
def disable_ui_on_spawn_sequence_start(evt : EventSpawnSequenceHeroInited)
  disable_ui()

[es(tag=gameClient, REQUIRE=eid)]
def enable_ui_on_spawn_sequence_end(evt : EventSpawnSequenceEnd)
  enable_ui()

[es(tag=gameClient, on_appear, REQUIRE=watchedByPlr)]
def enable_ui_on_reconnect(evt : Event; spawn_sequence_controller__state : int)
  if spawn_sequence_controller__state == int(SpawnSequenceControllerState.DONE)
    enable_ui()

[es(tag=gameClient, on_event=CmdEnableUi)]
def enable_ui_on_event(evt : Event)
  enable_ui()

[es(tag=gameClient, on_event=CmdDisableUi)]
def disable_ui_on_event(evt : Event)
  disable_ui()
