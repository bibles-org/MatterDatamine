require ecs
require HumanPhys
require math.base
require DngHuman
require app
require game.events.events
require DngCamera
require game.es.game_effect_macro


[es(tag=gameClient, REQUIRE=hero)]
def climbing_client_hint_act(update : CmdPostPhysUpdate;
                             isAlive : bool;
                             isDowned : bool;
                             isInVehicle : bool;
                             camera__lookDir : float3;
                             var human_net_phys : HumanActor)
  query() <| $ [es] (climbing_hint__maxDistBetweenHints : float;
                     climbing_hint__delay : float;
                     climbing_hint__dot : float;
                     var climbing_hint__tick : float&;
                     var transform : float3x4&;
                     var climbing_hint__hide : bool&;
                     var climbing_hint__haveEnoughStamina : bool&;
                     var climbing_hint__overObstacle : bool&)

    assume phys = human_net_phys.phys
    assume currentState = phys.currentState

    climbing_hint__hide = true

    if (!isAlive || isDowned || isInVehicle ||
        human_phys_state_get_isClimbing(currentState))
      return

    var tm : float3x4
    human_net_phys.phys.currentState.location |> location_toTM(tm)
    var gun_node_proj = tm[3]
    if phys.hasGuns
      var gunTm : float3x4
      human_phys_calcGunTm(phys, PrecomputedPresetMode.TPV, tm, currentState.gunAngles.y, currentState.leanPosition, currentState.height, gunTm)
      let toGunNodePos = gunTm[3] - tm[3]
      gun_node_proj = tm[3] + currentState.vertDirection * dot(toGunNodePos, currentState.vertDirection)

    let isInAir = (uint(human_net_phys.phys.currentState.isInAirHistory) & 1u) != 0u

    // simulating trying climbing. if this function found that we can climb, currentState.climbToPos will be set to the position where we can climb
    // after this we need update pos for climbing_hint entity and reset climbing state
    human_phys_tryClimbing(phys, true, isInAir, gun_node_proj, get_sync_time())

    if human_phys_state_get_isClimbing(currentState)
      let climbToPos = currentState.climbToPos
      let isOverObstacle = human_phys_state_get_isClimbingOverObstacle(currentState)
      human_phys_resetClimbing(phys)

      let camItm = get_TMatrix(get_cur_cam_entity(), "transform")
      if camItm == null
        return

      let cameraPos = (*camItm)[3]
      let distBetweenLastHintPosAndCurrentPos = distance_sq(climbToPos, transform[3])
      let allowableDist = distBetweenLastHintPosAndCurrentPos <= climbing_hint__maxDistBetweenHints
      let allowableDot = dot(normalize(climbToPos - cameraPos), camera__lookDir) >= climbing_hint__dot

      if allowableDist && allowableDot
        climbing_hint__tick += update.dt
        if climbing_hint__tick >= climbing_hint__delay
          climbing_hint__hide = false
          climbing_hint__haveEnoughStamina = currentState.stamina > phys.getClimbStaminaDrain
          climbing_hint__overObstacle = isOverObstacle
      else
        climbing_hint__tick = 0f
        transform[3] = climbToPos
    else
      climbing_hint__tick = 0f


[es(tag=gameClient, track=human_climbing_hint__enabled)]
def disable_climbing_hint(evt : Event;
                          human_climbing_hint__enabled : bool;
                          human_climbing_hint__hintTemplate : string)
  let hintEid = getSingletonEntity(human_climbing_hint__hintTemplate)
  if !human_climbing_hint__enabled && hintEid != INVALID_ENTITY_ID
    destroyEntity(hintEid)
  elif hintEid == INVALID_ENTITY_ID
    createEntity(human_climbing_hint__hintTemplate)


[es_game_effect(bool_flag=human_climbing_hint__enabled, tag=game_effect__disableClimbingHint, invert=true)]
def disable_climbing_hint_game_effect() { pass; }


[es(tag=gameClient, on_appear, REQUIRE=hero)]
def creation_climbing_hint_entity(evt : Event; human_climbing_hint__hintTemplate : string)
  let hintEid = getSingletonEntity(human_climbing_hint__hintTemplate)
  if hintEid == INVALID_ENTITY_ID
    createEntity(human_climbing_hint__hintTemplate)

[es(tag=gameClient, on_disappear, REQUIRE=hero)]
def deleting_climbing_hint_entity(evt : Event; human_climbing_hint__hintTemplate : string)
  let hintEid = getSingletonEntity(human_climbing_hint__hintTemplate)
  if hintEid != INVALID_ENTITY_ID
    destroyEntity(hintEid)