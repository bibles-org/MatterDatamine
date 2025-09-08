require ecs
require ecs.safe
require math.base
require math
require DagorMath
require AnimV20
require GeomNodeTree
require game.utils.team
require game.es.nexus_common
require game.es.nexus_beacon_common
require game.events.events_active_matter


[es(tag=gameClient, track=nexus_beacon__controllingTeam)]
def nexus_beacon_controlled_by_allies_update(evt : Event;
                                             nexus_beacon__controllingTeam : int;
                                             var nexus_beacon__controlledByAllies : bool&)
  find_query() <| $ [es(REQUIRE=hero)] (team : int)
    nexus_beacon__controlledByAllies = nexus_beacon__controllingTeam == team
    return true


[es(tag=gameClient, no_order)]
def nexus_beacon_progress_visual_update(update : UpdateStageInfoAct;
                                        nexus_beacon__captureDevices : EidList;
                                        nexus_beacon__progress : float;
                                        nexus_beacon__progressToCapture : float;
                                        nexus_beacon__progressVisualSpeedPerSec : float;
                                        nexus_beacon__controlledByAllies : bool;
                                        var nexus_beacon__progressVisual : float&)
  let progress = cvt(nexus_beacon__progress, 0.0, nexus_beacon__progressToCapture, 0.0, 1.0)
  let goalProgress = nexus_beacon__controlledByAllies ? progress : -progress
  let maxDelta = update.dt * nexus_beacon__progressVisualSpeedPerSec
  let delta = goalProgress - nexus_beacon__progressVisual
  if delta > maxDelta
    nexus_beacon__progressVisual += maxDelta
  elif delta < -maxDelta
    nexus_beacon__progressVisual -= maxDelta
  else
    nexus_beacon__progressVisual = goalProgress

  for captureDevice in nexus_beacon__captureDevices
    query(captureDevice) <| $ [es] (var nexus_beacon_capture_device__progressVisual : float&)
      nexus_beacon_capture_device__progressVisual = nexus_beacon__progressVisual


[es(tag=gameClient, track=(nexus_beacon__state, nexus_beacon__captureTeam, nexus_beacon__controllingTeam, nexus_beacon__captureDevices), on_appear)]
def nexus_beacon_capture_device_color_change(evt : Event;
                                             nexus_beacon__captureDevices : EidList;
                                             nexus_beacon__state : int;
                                             nexus_beacon__captureTeam : int;
                                             nexus_beacon__controllingTeam : int)
  for captureDevice in nexus_beacon__captureDevices
    query(captureDevice) <| $ [es] (nexus_beacon_capture_device__emissionInactiveColor : E3DCOLOR;
                                    nexus_beacon_capture_device__lightInactiveColor : E3DCOLOR;
                                    nexus_beacon_capture_device__emissionCooldownColor : E3DCOLOR;
                                    nexus_beacon_capture_device__lightCooldownColor : E3DCOLOR;
                                    nexus_beacon_capture_device__emissionAllyColor : E3DCOLOR;
                                    nexus_beacon_capture_device__lightAllyColor : E3DCOLOR;
                                    nexus_beacon_capture_device__emissionEnemyColor : E3DCOLOR;
                                    nexus_beacon_capture_device__lightEnemyColor : E3DCOLOR;
                                    var nexus_beacon_capture_device__emissionColor : E3DCOLOR&;
                                    var nexus_beacon_capture_device__lightColor : E3DCOLOR&)
      if nexus_beacon__state == int(NexusBeaconState.INACTIVE)
        nexus_beacon_capture_device__emissionColor = nexus_beacon_capture_device__emissionInactiveColor
        nexus_beacon_capture_device__lightColor = nexus_beacon_capture_device__lightInactiveColor
      elif nexus_beacon__state == int(NexusBeaconState.COOLDOWN)
        nexus_beacon_capture_device__emissionColor = nexus_beacon_capture_device__emissionCooldownColor
        nexus_beacon_capture_device__lightColor = nexus_beacon_capture_device__lightCooldownColor
      elif nexus_beacon__state == int(NexusBeaconState.CHANGING)
        if get_local_player_team() == nexus_beacon__captureTeam
          nexus_beacon_capture_device__emissionColor = nexus_beacon_capture_device__emissionAllyColor
          nexus_beacon_capture_device__lightColor = nexus_beacon_capture_device__lightAllyColor
        else
          nexus_beacon_capture_device__emissionColor = nexus_beacon_capture_device__emissionEnemyColor
          nexus_beacon_capture_device__lightColor = nexus_beacon_capture_device__lightEnemyColor
      elif nexus_beacon__state == int(NexusBeaconState.CAPTURED)
        if get_local_player_team() == nexus_beacon__controllingTeam
          nexus_beacon_capture_device__emissionColor = nexus_beacon_capture_device__emissionAllyColor
          nexus_beacon_capture_device__lightColor = nexus_beacon_capture_device__lightAllyColor
        else
          nexus_beacon_capture_device__emissionColor = nexus_beacon_capture_device__emissionEnemyColor
          nexus_beacon_capture_device__lightColor = nexus_beacon_capture_device__lightEnemyColor


[es(tag=gameClient, no_order)]
def nexus_beacon_capture_device_update_children_visual(update : ParallelUpdateFrameDelayed;
                                                       nexus_beacon_capture_device__animchar : EntityId;
                                                       nexus_beacon_capture_device__light : EntityId;
                                                       nexus_beacon_capture_device__emissionColor : E3DCOLOR;
                                                       nexus_beacon_capture_device__lightColor : E3DCOLOR)
  query(nexus_beacon_capture_device__animchar) <| $ [es] (var animchar_with_dynamic_emission__color : E3DCOLOR&)
    animchar_with_dynamic_emission__color = nexus_beacon_capture_device__emissionColor
  query(nexus_beacon_capture_device__light) <| $ [es] (var light__color : E3DCOLOR&)
    light__color = nexus_beacon_capture_device__lightColor


[es(tag=gameClient, on_appear)]
def init_nexus_militant_channeling_node_id(evt : Event;
                                           nexus_militant__channelingNodeName : string;
                                           animchar : AnimcharBaseComponent;
                                           var nexus_militant__channelingNodeId : int&)
  nexus_militant__channelingNodeId = geomtree_findNodeIndex(*animchar.nodeTree, nexus_militant__channelingNodeName)


def get_channeling_start_position(animchar : AnimcharBaseComponent; nexus_militant__channelingNodeId : int)
  return geomtree_getNodeWpos(*animchar.nodeTree, nexus_militant__channelingNodeId)


[es(tag=gameClient, no_order)]
def draw_human_nexus_channeling_effect(update : ParallelUpdateFrameDelayed;
                                       human_nexus_channeling_effect__pointEid : EntityId;
                                       human_nexus_channeling_effect__flySpeed : float;
                                       human_nexus_channeling_effect__requiredDistanceToTarget : float;
                                       human_nexus_channeling_effect__goal : float3;
                                       human_nexus_channeling_effect__owner : EntityId)
  query(human_nexus_channeling_effect__owner) <| $ [es] (animchar : AnimcharBaseComponent; nexus_militant__channelingNodeId : int)
    query(human_nexus_channeling_effect__pointEid) <| $ [es] (var transform aka point_transform : float3x4&)
      let dir = human_nexus_channeling_effect__goal - point_transform[3]
      let len = length(dir)
      if len > human_nexus_channeling_effect__requiredDistanceToTarget
        let speed = human_nexus_channeling_effect__flySpeed * update.dt
        let move = dir * safediv(speed, len)
        point_transform[3] += move
      else
        point_transform[3] = get_channeling_start_position(animchar, nexus_militant__channelingNodeId)


[es(tag=gameClient, on_disappear)]
def cleanup_channeling_nexus_effect_point(evt : Event; human_nexus_channeling_effect__pointEid : EntityId)
  destroyEntity(human_nexus_channeling_effect__pointEid)


[es(tag=gameClient, on_appear)]
def init_channeling_nexus_effect_point(evt : Event;
                                       human_nexus_channeling_effect__owner : EntityId;
                                       var human_nexus_channeling_effect__pointEid : EntityId&)
  query(human_nexus_channeling_effect__owner) <| $ [es] (animchar : AnimcharBaseComponent; nexus_militant__channelingNodeId : int)
    human_nexus_channeling_effect__pointEid = createEntity("human_nexus_channeling_effect_point") <| $(init)
      var tm = IDENT_TM
      tm[3] = get_channeling_start_position(animchar, nexus_militant__channelingNodeId)
      init |> set("transform", tm)
