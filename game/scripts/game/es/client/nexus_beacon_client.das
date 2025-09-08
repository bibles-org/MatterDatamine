require ecs
require Dacoll
require DngCamera
require DagorMathUtils
require game.events.events_active_matter
require net
require DagorInput
require math.base
require game.es.use_query_params_common
require game.es.nexus_beacon_common


def is_militant_looking_at_beacon(beacon_position : float3;
                                  beacon_interaction_distance : float;
                                  beacon_interaction_radius : float)
  var result = false
  query(get_cur_cam_entity()) <| $ [es] (transform aka camera_transform : float3x4)
    let lookFrom = camera_transform[3]
    let lookTo = lookFrom + camera_transform[2]
    if distance_sq(lookFrom, beacon_position) > square(beacon_interaction_distance)
      return
    if !test_segment_sphere_intersection(lookFrom, lookTo, beacon_position, square(beacon_interaction_radius))
      return
    // TODO: check against world collision to prevent looking through walls and objects
    result = true
  return result


[es(tag=gameClient, REQUIRE=hero, before=(selecting_extraction_artifact, hero_human_final_use_object_sync), after=(hero_human_pre_use_object_es, hero_human_use_object))]
def selecting_nexus_beacon(info : UpdateStageInfoAct;
                           team aka militant_team : int;
                           eid aka militant_eid : EntityId;
                           nexus_militant__capturingBeaconEid : EntityId;
                           var human_use_object__canUseSelected : bool&;
                           var human_use_object__selectedObject : EntityId&)
  if nexus_militant__capturingBeaconEid != INVALID_ENTITY_ID
    human_use_object__selectedObject = nexus_militant__capturingBeaconEid
    return
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    let params = get_use_query_params(militant_eid)
    var anotherObjectSelected = false
    query(human_use_object__selectedObject) <| $ [es] (transform aka container_transform : float3x4)
      let containerPos = container_transform[3]
      let dir = normalize(containerPos - params.pos)
      let t = length(containerPos - params.pos)
      anotherObjectSelected = dot(params.dir, dir) >= 0.95f && !rayhit_normalized(params.pos, dir, t, ETF_DEFAULT, -1)
    if anotherObjectSelected
      return

  find_query() <| $ [es(REQUIRE=nexus_beacon_capture_device, REQUIRE_NOT=nexus_beacon_capture_device_inactive)] (eid aka nexus_beacon_capture_device_eid : EntityId;
                                                                                                                 nexus_beacon_capture_device__beacon : EntityId;
                                                                                                                 nexus_beacon_capture_device__capturingMilitant : EntityId;
                                                                                                                 transform aka nexus_beacon_capture_device_transform : float3x4;
                                                                                                                 nexus_beacon_capture_device__interactionDistance : float;
                                                                                                                 nexus_beacon_capture_device__interactionRadius : float;
                                                                                                                 nexus_beacon_capture_device__activationPrompt : string;
                                                                                                                 nexus_beacon_capture_device__inUsePrompt : string;
                                                                                                                 nexus_beacon_capture_device__capturedPrompt : string;
                                                                                                                 var item__setCustomUsePrompt : das_string&;
                                                                                                                 var item__useActionAvailable : bool&)
    if !is_militant_looking_at_beacon(nexus_beacon_capture_device_transform[3], nexus_beacon_capture_device__interactionDistance, nexus_beacon_capture_device__interactionRadius)
      return false
    query(nexus_beacon_capture_device__beacon) <| $ [es] (nexus_beacon__state : int;
                                                          nexus_beacon__controllingTeam : int)
      var canUse = true
      var selectIfCantUse = false
      if nexus_beacon__controllingTeam == militant_team && nexus_beacon__state == int(NexusBeaconState.CAPTURED)
        canUse = false
        selectIfCantUse = true
        item__setCustomUsePrompt := nexus_beacon_capture_device__capturedPrompt
      elif nexus_beacon_capture_device__capturingMilitant == militant_eid
        canUse = false
      elif nexus_beacon_capture_device__capturingMilitant != INVALID_ENTITY_ID
        canUse = false
        selectIfCantUse = true
        item__setCustomUsePrompt := nexus_beacon_capture_device__inUsePrompt


      item__useActionAvailable = canUse
      if canUse
        human_use_object__selectedObject = nexus_beacon_capture_device_eid
        human_use_object__canUseSelected = true
        item__setCustomUsePrompt := nexus_beacon_capture_device__activationPrompt
      elif selectIfCantUse
        human_use_object__selectedObject = nexus_beacon_capture_device_eid
        human_use_object__canUseSelected = false
    return true


[es(tag=input)]
def nexus_beacon_sustain_capturing_client(update : ParallelUpdateFrameDelayed;
                                          eid aka hero_eid : EntityId;
                                          human_input__use : int;
                                          nexus_militant__capturingBeaconEid : EntityId)
  if nexus_militant__capturingBeaconEid == INVALID_ENTITY_ID
    return

  query(nexus_militant__capturingBeaconEid) <| $ [es(REQUIRE=nexus_beacon_capture_device)] (nexus_beacon_capture_device__capturingMilitant : EntityId;
                                                                                            transform aka nexus_beacon_capture_device_transform : float3x4;
                                                                                            nexus_beacon_capture_device__interactionDistance : float;
                                                                                            nexus_beacon_capture_device__interactionRadius : float;
                                                                                            nexus_beacon_capture_device__continuePrompt : string;
                                                                                            var item__setCustomUsePrompt : das_string)
    // In case when player started and stopped channeling very quickly
    // wait for server to acknoledge start so leave request would not
    // arrive sooner then enter request
    if hero_eid != nexus_beacon_capture_device__capturingMilitant
      return

    let handle = uint16(human_input__use)
    let btnPressed = is_action_active(handle) && get_digital_action_state(handle).bState
    if !btnPressed || !is_militant_looking_at_beacon(nexus_beacon_capture_device_transform[3], nexus_beacon_capture_device__interactionDistance, nexus_beacon_capture_device__interactionRadius)
      send_net_event(hero_eid, RequestNexusStopCapturingBeacon(beaconEid = nexus_militant__capturingBeaconEid))
    else
      item__setCustomUsePrompt := nexus_beacon_capture_device__continuePrompt


[es(tag=input, track=nexus_beacon_capture_device__capturingMilitant)]
def nexus_beacon_ensure_capturing(evt : Event;
                                  eid aka nexus_beacon_capture_device_eid : EntityId;
                                  nexus_beacon_capture_device__capturingMilitant : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId;
                                   nexus_militant__capturingBeaconEid : EntityId)
    if nexus_militant__capturingBeaconEid == INVALID_ENTITY_ID && nexus_beacon_capture_device__capturingMilitant == hero_eid
      send_net_event(hero_eid, RequestNexusStopCapturingBeacon(beaconEid = nexus_beacon_capture_device_eid))
      // this may happen if RequestNexusStopCapturingBeacon that was sent by nexus_beacon_sustain_capturing_client
      // arrived before CmdUse took effect on the server (unlike RequestNexusStopCapturingBeacon, CmdUse is delayed by 1 frame and the order may swap)
