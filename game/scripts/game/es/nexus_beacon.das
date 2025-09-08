require app
require ecs
require ecs.common
require DngNet
require DngHuman
require AnimV20
require GeomNodeTree
require DagorMathUtils
require Dacoll
require game.events.events
require game.events.events_active_matter
require game.es.nexus_common
require game.es.nexus_beacon_common
require math.base
require math.random
require game.utils.net_utils


def nexus_beacon_captured(beacon_eid : EntityId;
                          militants : EidList;
                          team : int;
                          time : float)
  sendEvent(beacon_eid, EventNexusBeaconCaptured(team = team))
  using() <| $(var players : EidList)
    for militant in militants
      query(militant) <| $ [es] (possessedByPlr : EntityId)
        if possessedByPlr != INVALID_ENTITY_ID
          players |> push(possessedByPlr)
    createEntity("nexus_history_beacon_capture+nexus_history_active") <| $(var init)
      init |> set("nexus_history__participants", players)
      init |> set("nexus_history__team", team)
      init |> set("nexus_history__at", time)


def nexus_beacon_reseted(beacon_eid : EntityId;
                         militants : EidList;
                         team : int;
                         time : float)
  sendEvent(beacon_eid, EventNexusBeaconReseted(team = team))
  using() <| $(var players : EidList)
    for militant in militants
      query(militant) <| $ [es] (possessedByPlr : EntityId)
        if possessedByPlr != INVALID_ENTITY_ID
          players |> push(possessedByPlr)
    createEntity("nexus_history_beacon_reset+nexus_history_active") <| $(var init)
      init |> set("nexus_history__participants", players)
      init |> set("nexus_history__team", team)
      init |> set("nexus_history__at", time)


def beacon_start_capture(beacon_eid : EntityId;
                         server : bool;
                         cur_time : float;
                         dt : float;
                         nexus_beacon__progressToCapture : float;
                         nexus_beacon__progressCapturePerSec : float;
                         nexus_beacon__captureTeam : int;
                         nexus_beacon__captureDeviceAdvantage : int;
                         nexus_beacon__captureMilitants : EidList;
                         var nexus_beacon__state : int&;
                         var nexus_beacon__controllingTeam : int&;
                         var nexus_beacon__progress : float&;
                         var nexus_beacon__lastSyncProgress : float&;
                         var nexus_beacon__lastSyncTime : float)
  nexus_beacon__progress += nexus_beacon__progressCapturePerSec * dt * float(nexus_beacon__captureDeviceAdvantage)
  var alreadyCaptured = false
  if nexus_beacon__progress >= nexus_beacon__progressToCapture
    nexus_beacon__progress = nexus_beacon__progressToCapture
    alreadyCaptured = true
  if server
    if alreadyCaptured
      nexus_beacon__controllingTeam = nexus_beacon__captureTeam
      nexus_beacon__state = int(NexusBeaconState.CAPTURED)
      nexus_beacon_captured(beacon_eid, nexus_beacon__captureMilitants, nexus_beacon__controllingTeam, cur_time)
    else
      nexus_beacon__controllingTeam = nexus_beacon__captureTeam
      nexus_beacon__state = int(NexusBeaconState.CHANGING)
    nexus_beacon__lastSyncProgress = nexus_beacon__progress
    nexus_beacon__lastSyncTime = cur_time


def beacon_start_reset(beacon_eid : EntityId;
                       server : bool;
                       cur_time : float;
                       dt : float;
                       nexus_beacon__progressCapturePerSec : float;
                       nexus_beacon__progressResetPerSec : float;
                       nexus_beacon__captureTeam : int;
                       nexus_beacon__captureDeviceAdvantage : int;
                       nexus_beacon__captureMilitants : EidList;
                       var nexus_beacon__state : int&;
                       var nexus_beacon__controllingTeam : int&;
                       var nexus_beacon__progress : float&;
                       var nexus_beacon__lastSyncProgress : float&;
                       var nexus_beacon__lastSyncTime : float)
  nexus_beacon__progress -= nexus_beacon__progressResetPerSec * dt * float(nexus_beacon__captureDeviceAdvantage)
  var alreadyReseted = false
  if nexus_beacon__progress <= 0.0
    nexus_beacon__progress = -nexus_beacon__progress
    nexus_beacon__progress = nexus_beacon__progress / nexus_beacon__progressResetPerSec * nexus_beacon__progressCapturePerSec
    alreadyReseted = true
  if server
    if nexus_beacon__state == int(NexusBeaconState.CAPTURED)
      nexus_beacon_reseted(beacon_eid, nexus_beacon__captureMilitants, nexus_beacon__controllingTeam, cur_time)
    if alreadyReseted
      nexus_beacon__controllingTeam = nexus_beacon__captureTeam
    nexus_beacon__state = int(NexusBeaconState.CHANGING)
    nexus_beacon__lastSyncProgress = nexus_beacon__progress
    nexus_beacon__lastSyncTime = cur_time


def progress_beacon(beacon_eid : EntityId;
                    server : bool;
                    cur_time : float;
                    dt : float;
                    nexus_beacon__progressToCapture : float;
                    nexus_beacon__progressCapturePerSec : float;
                    nexus_beacon__progressResetPerSec : float;
                    nexus_beacon__progressCooldownPerSec : float;
                    nexus_beacon__captureTeam : int;
                    nexus_beacon__captureDeviceAdvantage : int;
                    nexus_beacon__captureMilitants : EidList;
                    var nexus_beacon__state : int&;
                    var nexus_beacon__controllingTeam : int&;
                    var nexus_beacon__progress : float&;
                    var nexus_beacon__lastSyncProgress : float&;
                    var nexus_beacon__lastSyncTime : float&)
  assume timeSinceSync = cur_time - nexus_beacon__lastSyncTime

  if nexus_beacon__state == int(NexusBeaconState.INACTIVE) && nexus_beacon__captureTeam != TEAM_UNASSIGNED && nexus_beacon__controllingTeam == TEAM_UNASSIGNED
    beacon_start_capture(beacon_eid, server, cur_time, dt, nexus_beacon__progressToCapture, nexus_beacon__progressCapturePerSec,
                         nexus_beacon__captureTeam, nexus_beacon__captureDeviceAdvantage, nexus_beacon__captureMilitants, nexus_beacon__state,
                         nexus_beacon__controllingTeam, nexus_beacon__progress, nexus_beacon__lastSyncProgress, nexus_beacon__lastSyncTime)

  elif nexus_beacon__state == int(NexusBeaconState.CAPTURED) && nexus_beacon__captureTeam != TEAM_UNASSIGNED && nexus_beacon__controllingTeam != nexus_beacon__captureTeam
    beacon_start_reset(beacon_eid, server, cur_time, dt, nexus_beacon__progressCapturePerSec, nexus_beacon__progressResetPerSec,
                       nexus_beacon__captureTeam, nexus_beacon__captureDeviceAdvantage, nexus_beacon__captureMilitants, nexus_beacon__state,
                       nexus_beacon__controllingTeam, nexus_beacon__progress, nexus_beacon__lastSyncProgress, nexus_beacon__lastSyncTime)

  elif nexus_beacon__state == int(NexusBeaconState.CHANGING) && nexus_beacon__controllingTeam != TEAM_UNASSIGNED
    if nexus_beacon__captureTeam == TEAM_UNASSIGNED
      nexus_beacon__progress -= nexus_beacon__progressCapturePerSec * dt
      var alreadyInactive = false
      if nexus_beacon__progress <= 0.0
        nexus_beacon__progress = 0.0
        alreadyInactive = true
      if server
        if alreadyInactive
          nexus_beacon__controllingTeam = TEAM_UNASSIGNED
          nexus_beacon__state = int(NexusBeaconState.INACTIVE)
        else
          nexus_beacon__state = int(NexusBeaconState.COOLDOWN)
        nexus_beacon__lastSyncProgress = nexus_beacon__progress
        nexus_beacon__lastSyncTime = cur_time
    elif nexus_beacon__captureTeam == nexus_beacon__controllingTeam
      nexus_beacon__progress = nexus_beacon__lastSyncProgress + nexus_beacon__progressCapturePerSec * timeSinceSync * float(nexus_beacon__captureDeviceAdvantage)
      if nexus_beacon__progress >= nexus_beacon__progressToCapture
        nexus_beacon__progress = nexus_beacon__progressToCapture
        if server
          nexus_beacon__state = int(NexusBeaconState.CAPTURED)
          nexus_beacon__lastSyncProgress = nexus_beacon__progress
          nexus_beacon__lastSyncTime = cur_time
          nexus_beacon_captured(beacon_eid, nexus_beacon__captureMilitants, nexus_beacon__controllingTeam, cur_time)
    else
      nexus_beacon__progress = nexus_beacon__lastSyncProgress - nexus_beacon__progressResetPerSec * timeSinceSync * float(nexus_beacon__captureDeviceAdvantage)
      if nexus_beacon__progress <= 0.0
        nexus_beacon__progress = -nexus_beacon__progress
        nexus_beacon__progress = nexus_beacon__progress / nexus_beacon__progressResetPerSec * nexus_beacon__progressCapturePerSec
        nexus_beacon__controllingTeam = nexus_beacon__captureTeam
        nexus_beacon__lastSyncProgress = nexus_beacon__progress
        nexus_beacon__lastSyncTime = cur_time
  elif nexus_beacon__state == int(NexusBeaconState.COOLDOWN) && nexus_beacon__controllingTeam != TEAM_UNASSIGNED
    if nexus_beacon__captureTeam == TEAM_UNASSIGNED
      nexus_beacon__progress = nexus_beacon__lastSyncProgress - nexus_beacon__progressCooldownPerSec * timeSinceSync
      if nexus_beacon__progress <= 0.0
        nexus_beacon__progress = 0.0
        if server
          nexus_beacon__state = int(NexusBeaconState.INACTIVE)
          nexus_beacon__controllingTeam = TEAM_UNASSIGNED
          nexus_beacon__lastSyncProgress = nexus_beacon__progress
          nexus_beacon__lastSyncTime = cur_time
    elif nexus_beacon__captureTeam == nexus_beacon__controllingTeam
      beacon_start_capture(beacon_eid, server, cur_time, dt, nexus_beacon__progressToCapture, nexus_beacon__progressCapturePerSec,
                           nexus_beacon__captureTeam, nexus_beacon__captureDeviceAdvantage, nexus_beacon__captureMilitants, nexus_beacon__state,
                           nexus_beacon__controllingTeam, nexus_beacon__progress, nexus_beacon__lastSyncProgress, nexus_beacon__lastSyncTime)
    else
      beacon_start_reset(beacon_eid, server, cur_time, dt, nexus_beacon__progressCapturePerSec, nexus_beacon__progressResetPerSec,
                         nexus_beacon__captureTeam, nexus_beacon__captureDeviceAdvantage, nexus_beacon__captureMilitants, nexus_beacon__state,
                         nexus_beacon__controllingTeam, nexus_beacon__progress, nexus_beacon__lastSyncProgress, nexus_beacon__lastSyncTime)


def beacon_start_capture_client(beacon_position : float3;
                                nexus_eid : EntityId;
                                militant_eid : EntityId;
                                var nexus_militant__capturingBeaconEid : EntityId&;
                                var nexus_militant__channelingVisualEffect : EntityId&;
                                var nexus_militant__channelingAnimEffect : EntityId&)
  if nexus_militant__capturingBeaconEid != INVALID_ENTITY_ID
    return

  nexus_militant__capturingBeaconEid = nexus_eid

  nexus_militant__channelingAnimEffect = createEntity("channeling_nexus_militant_effect") <| $(init)
    init |> set("game_effect__attachedTo", militant_eid)

  nexus_militant__channelingVisualEffect = createEntity("human_nexus_channeling_effect") <| $(init)
    init |> set("human_nexus_channeling_effect__goal", beacon_position)
    init |> set("human_nexus_channeling_effect__owner", militant_eid)


def beacon_stop_capture_client(var nexus_militant__capturingBeaconEid : EntityId&;
                               var nexus_militant__channelingVisualEffect : EntityId&;
                               var nexus_militant__channelingAnimEffect : EntityId&)
  nexus_militant__capturingBeaconEid = INVALID_ENTITY_ID

  destroyEntity(nexus_militant__channelingAnimEffect)
  nexus_militant__channelingAnimEffect = INVALID_ENTITY_ID

  destroyEntity(nexus_militant__channelingVisualEffect)
  nexus_militant__channelingVisualEffect = INVALID_ENTITY_ID


[es(tag=server, on_appear)]
def nexus_beacon_init(evt : Event;
                      eid aka nexus_beacon_eid : EntityId;
                      nexus_beacon__id : int;
                      var nexus_beacon__captureDevices : EidList&)
  query() <| $ [es] (eid aka nexus_beacon_capture_device_eid : EntityId;
                     nexus_beacon_capture_device__parentId : int;
                     var nexus_beacon_capture_device__beacon : EntityId&)
    if nexus_beacon__id == nexus_beacon_capture_device__parentId && nexus_beacon_capture_device__beacon == INVALID_ENTITY_ID
      nexus_beacon__captureDevices |> push(nexus_beacon_capture_device_eid)
      nexus_beacon_capture_device__beacon = nexus_beacon_eid


[es(tag=server, REQUIRE=nexus_beacon_capture_device_animchar, on_appear)]
def nexus_beacon_capture_device_animchar_init(evt : Event;
                                              eid : EntityId)
  find_query() <| $ [es(REQUIRE=nexus_beacon_capture_device)] (composit_holder__childrenEids : EidList;
                                                               var nexus_beacon_capture_device__animchar : EntityId&)
    if composit_holder__childrenEids |> find_index(eid) == -1
      return false
    nexus_beacon_capture_device__animchar = eid
    return true


[es(tag=server, REQUIRE=nexus_beacon_capture_device_light, on_appear)]
def nexus_beacon_capture_device_light_init(evt : Event;
                                           eid : EntityId)
  find_query() <| $ [es(REQUIRE=nexus_beacon_capture_device)] (composit_holder__childrenEids : EidList;
                                                               var nexus_beacon_capture_device__light : EntityId&)
    if composit_holder__childrenEids |> find_index(eid) == -1
      return false
    nexus_beacon_capture_device__light = eid
    return true


[es(tag=server, on_appear)]
def nexus_beacon_capture_device_init(evt : Event;
                                     eid aka nexus_beacon_capture_device_eid : EntityId;
                                     nexus_beacon_capture_device__parentId : int;
                                     var nexus_beacon_capture_device__beacon : EntityId&)
  if nexus_beacon_capture_device__beacon != INVALID_ENTITY_ID
    return
  query() <| $ [es] (eid aka nexus_beacon_eid : EntityId;
                     nexus_beacon__id : int;
                     var nexus_beacon__captureDevices : EidList&)
    if nexus_beacon__id == nexus_beacon_capture_device__parentId
      nexus_beacon__captureDevices |> push(nexus_beacon_capture_device_eid)
      nexus_beacon_capture_device__beacon = nexus_beacon_eid


[es(tag=server, on_appear)]
def nexus_beacon_precapture(evt : Event;
                            nexus_beacon__precapturedForTeam : int;
                            nexus_beacon__progressToCapture : float;
                            var nexus_beacon__state : int&;
                            var nexus_beacon__controllingTeam : int&;
                            var nexus_beacon__progress : float&)
  nexus_beacon__state = int(NexusBeaconState.CAPTURED)
  nexus_beacon__controllingTeam = nexus_beacon__precapturedForTeam
  nexus_beacon__progress = nexus_beacon__progressToCapture


[es(tag=server, track=nexus_beacon__captureDevices)]
def nexus_beacon_random_capture_devices_init(evt : Event;
                                             nexus_beacon__allCaptureDevicesCount : int;
                                             nexus_beacon__randomCaptureDevicesCount : int;
                                             var nexus_beacon__captureDevices : EidList&)
  if length(nexus_beacon__captureDevices) != nexus_beacon__allCaptureDevicesCount
    return

  var devicesToDestroyIndex : array<int>
  var devicesToDestroyEid : array<EntityId>
  let devicesCount = length(nexus_beacon__captureDevices)
  let devicesToDestroyCount = length(nexus_beacon__captureDevices) - nexus_beacon__randomCaptureDevicesCount
  for i in range(0, devicesCount)
    devicesToDestroyIndex |> push(i)
  shuffle(devicesToDestroyIndex, devicesToDestroyCount)

  for i in range(0, devicesToDestroyCount)
    let deviceToDestroyIndex = devicesToDestroyIndex[i]
    let deviceToDestroyEid = nexus_beacon__captureDevices[deviceToDestroyIndex]
    devicesToDestroyEid |> push(deviceToDestroyEid)

  for deviceToDestroyEid in devicesToDestroyEid
    let deviceToDestroyIndex = nexus_beacon__captureDevices |> find_index(deviceToDestroyEid)
    if deviceToDestroyIndex >= 0
      nexus_beacon__captureDevices |> erase(deviceToDestroyIndex)
    remote_add_sub_template(deviceToDestroyEid, "nexus_disable+nexus_beacon_capture_device_inactive")


[es(REQUIRE=(nexus_beacon_capture_device_animchar, nexus_disable), on_appear)]
def nexus_beacon_capture_device_animchar_disable(evt : Event;
                                                 var animchar_render__enabled : bool&)
  animchar_render__enabled = false


[es(REQUIRE=(nexus_beacon_capture_device_light, nexus_disable), on_appear)]
def nexus_beacon_capture_device_light_disable(evt : Event;
                                              var light__brightness : float&)
  light__brightness = 0.0


[es(REQUIRE=(nexus_beacon_capture_device, nexus_disable), track=composit_holder__childrenEids, on_appear)]
def nexus_beacon_capture_device_disable(evt : Event;
                                        composit_holder__childrenEids : EidList)
  for childrenEid in composit_holder__childrenEids
    if !has(childrenEid, "nexus_disable")
      remote_add_sub_template(childrenEid, "nexus_disable")


// For offline mode only
// CmdUse usually is sent on server and HumanUseObjectRequest is sent on the client,
// but in offline mode HumanUseObjectRequest is skipped
[es(tag=(gameClient, server), REQUIRE=nexus_beacon_capture_device)]
def nexus_beacon_capture_device_start_capturing_client_offline(evt : CmdUse;
                                                               transform : float3x4;
                                                               eid : EntityId)
  query(evt.requesterEid) <| $ [es] (var nexus_militant__capturingBeaconEid : EntityId&;
                                     var nexus_militant__channelingVisualEffect : EntityId&;
                                     var nexus_militant__channelingAnimEffect : EntityId&)
    beacon_start_capture_client(transform[3],
                                eid,
                                evt.requesterEid,
                                nexus_militant__capturingBeaconEid,
                                nexus_militant__channelingVisualEffect,
                                nexus_militant__channelingAnimEffect)
    nexus_log("BEACON", "(OFFLINE) Start capturing of beacon<{nexus_militant__capturingBeaconEid}> (animEffect<{nexus_militant__channelingAnimEffect}>; visualEffect<{nexus_militant__channelingVisualEffect}>)")


[es(tag=gameClient)]
def nexus_beacon_capture_device_start_capturing_client(evt : HumanUseObjectRequest;
                                                       eid : EntityId;
                                                       var nexus_militant__capturingBeaconEid : EntityId&;
                                                       var nexus_militant__channelingVisualEffect : EntityId&;
                                                       var nexus_militant__channelingAnimEffect : EntityId&)
  query(evt.objectEid) <| $ [es(REQUIRE=nexus_beacon_capture_device)] (transform : float3x4)
    beacon_start_capture_client(transform[3],
                                evt.objectEid,
                                eid,
                                nexus_militant__capturingBeaconEid,
                                nexus_militant__channelingVisualEffect,
                                nexus_militant__channelingAnimEffect)
    nexus_log("BEACON", "Start capturing of beacon<{nexus_militant__capturingBeaconEid}> (animEffect<{nexus_militant__channelingAnimEffect}>; visualEffect<{nexus_militant__channelingVisualEffect}>)")


[es(tag=server, REQUIRE_NOT=nexus_beacon_capture_device_inactive)]
def nexus_beacon_capture_device_start_capturing_server(evt : CmdUse;
                                                       eid : EntityId;
                                                       transform : float3x4;
                                                       nexus_beacon_capture_device__interactionRadius : float;
                                                       nexus_beacon_capture_device__interactionDistance : float;
                                                       var nexus_beacon_capture_device__capturingMilitant : EntityId&;
                                                       var nexus_beacon_capture_device__capturingTeam : int&)
  if nexus_beacon_capture_device__capturingMilitant != INVALID_ENTITY_ID
    nexus_log("BEACON", "Player<{evt.requesterEid}> can't start capturing the device<{eid}> due to another player<{nexus_beacon_capture_device__capturingMilitant}> performing a capture")
    return

  query(evt.requesterEid) <| $ [es] (team : int;
                                     human_net_phys : HumanActor;
                                     animchar : AnimcharBaseComponent;
                                     human_use_object__nodeId : int)
    let lookFrom = geomtree_getNodeWpos(*animchar.nodeTree, human_use_object__nodeId)
    let lookDir = normalize(human_net_phys.phys.appliedCT.wishLookDir)
    var traceDist = nexus_beacon_capture_device__interactionDistance
    var norm : float3
    traceray_normalized(lookFrom, lookDir, traceDist, norm, ETF_DEFAULT)
    let lookTo = lookFrom + lookDir * traceDist
    if !test_segment_sphere_intersection(lookFrom, lookTo, transform[3], square(nexus_beacon_capture_device__interactionRadius))
      nexus_log("BEACON", "Player<{evt.requesterEid}> can't start capturing the device<{eid}>: they don't look at it ")
      return
    nexus_beacon_capture_device__capturingMilitant = evt.requesterEid
    nexus_beacon_capture_device__capturingTeam = team


[es(tag=gameClient, on_event=(RequestNexusStopCapturingBeacon, EventNexusStopCapturingBeacon))]
def nexus_beacon_capture_device_stop_capturing_client(evt : Event;
                                                      var nexus_militant__channelingAnimEffect : EntityId&;
                                                      var nexus_militant__channelingVisualEffect : EntityId&;
                                                      var nexus_militant__capturingBeaconEid : EntityId&)
  nexus_log("BEACON", "Stop capturing of beacon<{nexus_militant__capturingBeaconEid}> (animEffect<{nexus_militant__channelingAnimEffect}>; visualEffect<{nexus_militant__channelingVisualEffect}>)")
  beacon_stop_capture_client(nexus_militant__capturingBeaconEid, nexus_militant__channelingVisualEffect, nexus_militant__channelingAnimEffect)


[es(tag=server)]
def nexus_beacon_capture_device_stop_capturing_server(evt : RequestNexusStopCapturingBeacon;
                                                      eid : EntityId)
  query(evt.beaconEid) <| $ [es(REQUIRE=nexus_beacon_capture_device)] (var nexus_beacon_capture_device__capturingMilitant : EntityId&;
                                                                       var nexus_beacon_capture_device__capturingTeam : int&)
    if eid != nexus_beacon_capture_device__capturingMilitant
      return
    nexus_beacon_capture_device__capturingMilitant = INVALID_ENTITY_ID
    nexus_beacon_capture_device__capturingTeam = -1


[es(tag=server, REQUIRE=nexus_beacon_capture_device__capturingTeam, track=nexus_beacon_capture_device__capturingTeam)]
def nexus_beacon_capture_device_update_beacon_devcie_advantage(evt : Event;
                                                               nexus_beacon_capture_device__beacon : EntityId)
  query(nexus_beacon_capture_device__beacon) <| $ [es] (nexus_beacon__captureDevices : EidList;
                                                        nexus_beacon__progress : float;
                                                        var nexus_beacon__captureTeam : int&;
                                                        var nexus_beacon__captureDeviceAdvantage : int&;
                                                        var nexus_beacon__captureMilitants : EidList&;
                                                        var nexus_beacon__lastSyncProgress : float&;
                                                        var nexus_beacon__lastSyncTime : float&)
    clear(nexus_beacon__captureMilitants)
    var teamOneCaptureDevicesCount = 0
    var teamTwoCaptureDevicesCount = 0
    for device in nexus_beacon__captureDevices
      query(device) <| $ [es] (nexus_beacon_capture_device__capturingMilitant : EntityId;
                               nexus_beacon_capture_device__capturingTeam : int)
        nexus_beacon__captureMilitants |> push(nexus_beacon_capture_device__capturingMilitant)
        if nexus_beacon_capture_device__capturingTeam == int(NexusTeam.FIRST)
          ++teamOneCaptureDevicesCount
        elif nexus_beacon_capture_device__capturingTeam == int(NexusTeam.SECOND)
          ++teamTwoCaptureDevicesCount

    var capturingTeam = TEAM_UNASSIGNED
    var deviceAdvantage = 0
    if teamOneCaptureDevicesCount > teamTwoCaptureDevicesCount
      capturingTeam = int(NexusTeam.FIRST)
      deviceAdvantage = teamOneCaptureDevicesCount - teamTwoCaptureDevicesCount
    elif teamOneCaptureDevicesCount < teamTwoCaptureDevicesCount
      capturingTeam = int(NexusTeam.SECOND)
      deviceAdvantage = teamTwoCaptureDevicesCount - teamOneCaptureDevicesCount

    if nexus_beacon__captureTeam != capturingTeam || nexus_beacon__captureDeviceAdvantage != deviceAdvantage
      nexus_beacon__captureTeam = capturingTeam
      nexus_beacon__captureDeviceAdvantage = deviceAdvantage
      nexus_beacon__lastSyncProgress = nexus_beacon__progress
      nexus_beacon__lastSyncTime = get_sync_time()


[es(tag=server)]
def nexus_beacon_on_capture(evt : EventNexusBeaconCaptured;
                            nexus_beacon__captureDevices : EidList)
  for captureDevice in nexus_beacon__captureDevices
    query(captureDevice) <| $ [es] (var nexus_beacon_capture_device__capturingMilitant : EntityId&;
                                    var nexus_beacon_capture_device__capturingTeam : int&)
      if nexus_beacon_capture_device__capturingMilitant != INVALID_ENTITY_ID
        send_net_event(nexus_beacon_capture_device__capturingMilitant, EventNexusStopCapturingBeacon(), target_entity_conn(nexus_beacon_capture_device__capturingMilitant))
      nexus_beacon_capture_device__capturingMilitant = INVALID_ENTITY_ID
      nexus_beacon_capture_device__capturingTeam = -1


[es(tag=server)]
def nexus_beacon_capture_device_verify_capture(evt : ParallelUpdateFrameDelayed;
                                               transform aka nexus_beacon_capture_device_transform : float3x4;
                                               nexus_beacon_capture_device__interactionDistance : float;
                                               var nexus_beacon_capture_device__capturingMilitant : EntityId&;
                                               var nexus_beacon_capture_device__capturingTeam : int&)
  if nexus_beacon_capture_device__capturingMilitant == INVALID_ENTITY_ID
    return

  var shouldStopCapturing = false
  query(nexus_beacon_capture_device__capturingMilitant) <| $ [es] (transform aka militant_transform : float3x4;
                                                                   isAlive : bool)
    if !isAlive
      shouldStopCapturing = true
      return
    if distance_sq(militant_transform[3], nexus_beacon_capture_device_transform[3]) > square(nexus_beacon_capture_device__interactionDistance + 2.0)
      shouldStopCapturing = true
      return
  if !shouldStopCapturing
    return

  nexus_beacon_capture_device__capturingMilitant = INVALID_ENTITY_ID
  nexus_beacon_capture_device__capturingTeam = -1


[es(tag=server, no_order)]
def nexus_beacon_update_server(act : UpdateStageInfoAct;
                               eid : EntityId;
                               nexus_beacon__progressToCapture : float;
                               nexus_beacon__progressCapturePerSec : float;
                               nexus_beacon__progressResetPerSec : float;
                               nexus_beacon__progressCooldownPerSec : float;
                               nexus_beacon__captureTeam : int;
                               nexus_beacon__captureDeviceAdvantage : int;
                               nexus_beacon__captureMilitants : EidList;
                               var nexus_beacon__state : int&;
                               var nexus_beacon__controllingTeam : int&;
                               var nexus_beacon__progress : float&;
                               var nexus_beacon__lastSyncProgress : float&;
                               var nexus_beacon__lastSyncTime : float&)
  progress_beacon(eid, true, act.curTime, act.dt, nexus_beacon__progressToCapture, nexus_beacon__progressCapturePerSec, nexus_beacon__progressResetPerSec,
                  nexus_beacon__progressCooldownPerSec, nexus_beacon__captureTeam, nexus_beacon__captureDeviceAdvantage, nexus_beacon__captureMilitants,
                  nexus_beacon__state, nexus_beacon__controllingTeam, nexus_beacon__progress, nexus_beacon__lastSyncProgress, nexus_beacon__lastSyncTime)


[es(tag=gameClient, no_order)]
def nexus_beacon_update_client(act : UpdateStageInfoAct;
                               eid : EntityId;
                               nexus_beacon__progressToCapture : float;
                               nexus_beacon__progressCapturePerSec : float;
                               nexus_beacon__progressResetPerSec : float;
                               nexus_beacon__progressCooldownPerSec : float;
                               nexus_beacon__captureTeam : int;
                               nexus_beacon__captureDeviceAdvantage : int;
                               nexus_beacon__captureMilitants : EidList;
                               var nexus_beacon__state : int&;
                               var nexus_beacon__controllingTeam : int&;
                               var nexus_beacon__progress : float&;
                               var nexus_beacon__lastSyncProgress : float&;
                               var nexus_beacon__lastSyncTime : float&)
  if is_server()
    return
  progress_beacon(eid, false, act.curTime, act.dt, nexus_beacon__progressToCapture, nexus_beacon__progressCapturePerSec, nexus_beacon__progressResetPerSec,
                  nexus_beacon__progressCooldownPerSec, nexus_beacon__captureTeam, nexus_beacon__captureDeviceAdvantage, nexus_beacon__captureMilitants,
                  nexus_beacon__state, nexus_beacon__controllingTeam, nexus_beacon__progress, nexus_beacon__lastSyncProgress, nexus_beacon__lastSyncTime)


[es(tag=gameClient, track=nexus_beacon__state)]
def nexus_beacon_track_state(evt : Event;
                             nexus_beacon__state : int;
                             nexus_beacon__progressToCapture : float;
                             var nexus_beacon__progress : float&)
  if nexus_beacon__state == int(NexusBeaconState.INACTIVE)
    nexus_beacon__progress = 0.0
  elif nexus_beacon__state == int(NexusBeaconState.CAPTURED)
    nexus_beacon__progress = nexus_beacon__progressToCapture
