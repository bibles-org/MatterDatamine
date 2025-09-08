require ecs
require net
require DngHuman
require game.events.events
require game.events.events_game
require game.utils.net_utils


[es(on_appear)]
def phys_state_init_syncer(evt : Event;
                           eid : EntityId;
                           var phys_state_syncer : ECSCustomPhysStateSyncer;
                           var human_net_phys : HumanActor;
                           var heartrate__value : float&;
                           var heartrate__stamina : float&;
                           var heartrate__amortization : float&;
                           var human_hand_stamina__stamina : float&;
                           var human_ladder__attached : bool&;
                           var human_ladder__detached : bool&;
                           var human_ladder__pull : bool&)
  phys_state_syncer |> init(eid, 7)

  phys_state_syncer |> registerSyncComponent("heartrate__value", heartrate__value)
  phys_state_syncer |> registerSyncComponent("heartrate__stamina", heartrate__stamina)
  phys_state_syncer |> registerSyncComponent("heartrate__amortization", heartrate__amortization)

  phys_state_syncer |> registerSyncComponent("human_hand_stamina__stamina", human_hand_stamina__stamina)

  // Note: try group bool (re)sync comps together for tighter serialization
  phys_state_syncer |> registerSyncComponent("human_ladder__attached", human_ladder__attached)
  phys_state_syncer |> registerSyncComponent("human_ladder__detached", human_ladder__detached)
  phys_state_syncer |> registerSyncComponent("human_ladder__pull", human_ladder__pull)

  human_net_phys.phys |> registerCustomPhysStateSyncer(phys_state_syncer)


[es(on_disappear)]
def phys_state_unreg_syncer(evt : Event;
                            var phys_state_syncer : ECSCustomPhysStateSyncer;
                            var human_net_phys : HumanActor)
  human_net_phys.phys |> unregisterCustomPhysStateSyncer(phys_state_syncer)


[es(tag=server, on_appear, REQUIRE=heartrate__value, REQUIRE_NOT=am_militant_bot)]
def heartrate_server_create_syncer(evt : Event; eid : EntityId; isAlive : bool)
  if isAlive
    addSubTemplate(eid, "am_phys_state_syncer")


[es(tag=server, REQUIRE=phys_state_syncer, track=isAlive)]
def heartrate_server_delete_syncer(evt : Event; eid : EntityId; isAlive : bool)
  if !isAlive
    removeSubTemplate(eid, "am_phys_state_syncer")


// sync for spectator
[es(tag=server, after=hearbeat_es)]
def sync_heartrate_server(cmd : CmdPostPhysUpdate;
                          eid : EntityId;
                          heartrate__syncPeriod : int;
                          heartrate__value : float)
  if cmd.tick % heartrate__syncPeriod == 0
    send_net_event(eid, EventSyncHeartRate(value = heartrate__value), spectated_only(eid))


[es(tag=netClient)]
def sync_heartrate_client(evt : EventSyncHeartRate; var heartrate__value : float&)
  heartrate__value = evt.value


[es(tag=server, after=human_hand_stamina_drain)]
def sync_hand_stamina_server(cmd : CmdPostPhysUpdate;
                             eid : EntityId;
                             human_hand_stamina__syncPeriod : int;
                             human_hand_stamina__stamina : float)
  if cmd.tick % human_hand_stamina__syncPeriod == 0
    send_net_event(eid, EventSyncHandStamina(value = human_hand_stamina__stamina), spectated_only(eid))


[es(tag=netClient)]
def sync_hand_stamina_client(evt : EventSyncHandStamina; var human_hand_stamina__stamina : float&)
  human_hand_stamina__stamina = evt.value
