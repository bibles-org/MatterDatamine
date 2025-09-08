require app
require ecs
require AnimV20
require DagorSystem
require game.events.events_active_matter
require game.es.human.human_parachute_common


[es(tag=gameClient, on_appear)]
def parachute_effect_attach_on_create(evt : Event;
                                      human_parachute_control_effect__attachedTo : EntityId;
                                      var human_parachute_effect__eid : EntityId&;
                                      human_parachute__effectTemplate : string;
                                      human_parachute__deployedAtTime : float;
                                      human_parachute__closedAtTime : float;
                                      human_parachute__isDeployed : bool)
  let parachuteEffectEid = createEntity(human_parachute__effectTemplate) <| $(init)
    init |> set("human_parachute_effect__attachedTo", human_parachute_control_effect__attachedTo)
    init |> set("human_parachute_anim__deployedAtTime", human_parachute__deployedAtTime)
    init |> set("human_parachute_anim__closedAtTime", human_parachute__closedAtTime)
    init |> set("human_parachute_effect__isOpened", human_parachute__isDeployed)
  human_parachute_effect__eid = parachuteEffectEid
  query(human_parachute_control_effect__attachedTo) <| $ [es] (var human_parachute_effect__eid : EntityId&)
    human_parachute_effect__eid = parachuteEffectEid


[es(tag=gameClient, on_appear)]
def parachute_effect_on_appear(evt : Event;
                               human_parachute_anim__deployedAtTime : float;
                               human_parachute_anim__closedAtTime : float;
                               human_parachute_anim__openDuration : float;
                               human_parachute_anim__closeDuration : float;
                               var human_parachute_anim__openAtTime : float&;
                               var human_parachute_anim__closeAtTime : float&;
                               var human_parachute_anim__currentState : int&;
                               human_parachute_effect__isOpened : bool;
                               human_parachute_effect__attachedTo : EntityId;
                               human_parachute__parachuteTemplate : string;
                               var human_parachute__eid : EntityId&)
  let cutTime = get_sync_time()
  if human_parachute_effect__isOpened
    human_parachute_anim__currentState = int(ParachuteState.OPENING)
    human_parachute_anim__openAtTime = human_parachute_anim__deployedAtTime + human_parachute_anim__openDuration
    if cutTime >= human_parachute_anim__openAtTime
      human_parachute_anim__currentState = int(ParachuteState.OPENED)
  elif !human_parachute_effect__isOpened && human_parachute_anim__deployedAtTime != 0.0
    human_parachute_anim__currentState = int(ParachuteState.CLOSING)
    human_parachute_anim__closeAtTime = human_parachute_anim__closedAtTime + human_parachute_anim__closeDuration
    if cutTime >= human_parachute_anim__closeAtTime
      human_parachute_anim__currentState = int(ParachuteState.CLOSED)
  if human_parachute_anim__currentState != int(ParachuteState.CLOSED)
    human_parachute__eid = createEntity(human_parachute__parachuteTemplate) <| $(init)
      init |> set("skeleton_attach__attached", true)
      init |> set("slot_attach__attachedTo", human_parachute_effect__attachedTo)
      init |> set("skeleton_attach__attachedTo", human_parachute_effect__attachedTo)
      init |> set("parachute_anim__isOpened", human_parachute_effect__isOpened)
      if human_parachute_anim__currentState == int(ParachuteState.CLOSING)
        init |> set("parachute_anim__lastDeployState", true)
      init |> set("parachute_anim__openedAtTime", human_parachute_anim__deployedAtTime)
      init |> set("parachute_anim__closedAtTime", human_parachute_anim__closedAtTime)


[es(tag=gameClient, track=human_parachute__isDeployed)]
def human_parachute_effect_deploy(evt : Event;
                                  human_parachute_effect__eid : EntityId;
                                  human_parachute__isDeployed : bool)
  query(human_parachute_effect__eid) <| $ [es] (var human_parachute_effect__isOpened : bool&;
                                                human_parachute__eid : EntityId)
    human_parachute_effect__isOpened = human_parachute__isDeployed
    query(human_parachute__eid) <| $ [es] (var parachute_anim__isOpened : bool&)
      parachute_anim__isOpened = human_parachute__isDeployed


[es(tag=gameClient, on_disappear)]
def human_parachute_effect_close(evt : Event;
                                 human_parachute_effect__eid : EntityId;
                                 human_parachute_control_effect__attachedTo : EntityId)
  let isHeroAlive = get_bool(human_parachute_control_effect__attachedTo, "isAlive") ?? false
  query(human_parachute_effect__eid) <| $ [es] (var human_parachute_effect__isOpened : bool&;
                                                var human_parachute_anim__currentState : int&;
                                                human_parachute__eid : EntityId)
    human_parachute_effect__isOpened = false
    if !isHeroAlive
      human_parachute_anim__currentState = int(ParachuteState.CLOSED)
    query(human_parachute__eid) <| $ [es] (var parachute_anim__isOpened : bool&)
      parachute_anim__isOpened = false


[es(tag=render, track=human_parachute_effect__isOpened)]
def human_parachute_camera_stabilization(evt : Event;
                                         human_parachute_effect__attachedTo : EntityId;
                                         human_parachute_effect__isOpened : bool)
  query(human_parachute_effect__attachedTo) <| $ [es] (var camera__isStabilized : bool&)
    if human_parachute_effect__isOpened
      camera__isStabilized = true
    else
      camera__isStabilized = false


[es(tag=gameClient, after=human_anim_es)]
def human_parachute_animation_state(act : ParallelUpdateFrameDelayed;
                                    human_parachute_anim__openDuration : float;
                                    human_parachute_anim__closeDuration : float;
                                    var human_parachute_anim__openAtTime : float&;
                                    var human_parachute_anim__closeAtTime : float&;
                                    var human_parachute_anim__currentState : int&;
                                    human_parachute_effect__isOpened : bool)
  if human_parachute_effect__isOpened && human_parachute_anim__currentState == int(ParachuteState.NONE)
    human_parachute_anim__currentState = int(ParachuteState.OPENING)
    human_parachute_anim__openAtTime = act.curTime + human_parachute_anim__openDuration
  elif human_parachute_effect__isOpened && human_parachute_anim__currentState == int(ParachuteState.OPENING)
    if act.curTime >= human_parachute_anim__openAtTime
      human_parachute_anim__currentState = int(ParachuteState.OPENED)
  elif !human_parachute_effect__isOpened && human_parachute_anim__currentState == int(ParachuteState.OPENED)
    human_parachute_anim__currentState = int(ParachuteState.CLOSING)
    human_parachute_anim__closeAtTime = act.curTime + human_parachute_anim__closeDuration
  elif !human_parachute_effect__isOpened && human_parachute_anim__currentState == int(ParachuteState.CLOSING)
    if act.curTime >= human_parachute_anim__closeAtTime
      human_parachute_anim__currentState = int(ParachuteState.CLOSED)


[es(tag=gameClient, track=human_parachute_anim__currentState)]
def human_parachute_animation_continuous(evt : Event;
                                         human_parachute_effect__attachedTo : EntityId;
                                         human_parachute_anim__currentState : int;
                                         var human_parachute_anim__currentEffect : EntityId&)
  if human_parachute_anim__currentState == int(ParachuteState.NONE)
    destroyEntity(human_parachute_anim__currentEffect)
  elif human_parachute_anim__currentState == int(ParachuteState.OPENING)
    if human_parachute_anim__currentEffect != INVALID_ENTITY_ID
      destroyEntity(human_parachute_anim__currentEffect)
    human_parachute_anim__currentEffect = createEntity("human_parachute_opening_animation") <| $(var init)
      set(init, "game_effect__attachedTo", human_parachute_effect__attachedTo)
  elif human_parachute_anim__currentState == int(ParachuteState.OPENED)
    if human_parachute_anim__currentEffect != INVALID_ENTITY_ID
      destroyEntity(human_parachute_anim__currentEffect)
    human_parachute_anim__currentEffect = createEntity("human_parachute_opened_animation") <| $(var init)
      set(init, "game_effect__attachedTo", human_parachute_effect__attachedTo)
  elif human_parachute_anim__currentState == int(ParachuteState.CLOSING)
    if human_parachute_anim__currentEffect != INVALID_ENTITY_ID
      destroyEntity(human_parachute_anim__currentEffect)
    human_parachute_anim__currentEffect = createEntity("human_parachute_close_animation") <| $(var init)
      set(init, "game_effect__attachedTo", human_parachute_effect__attachedTo)
  elif human_parachute_anim__currentState == int(ParachuteState.CLOSED)
    destroyEntity(human_parachute_anim__currentEffect)


[es(tag=gameClient, on_disappear)]
def human_parachute_animation_clear(evt : Event; human_parachute_anim__currentEffect : EntityId)
  if human_parachute_anim__currentEffect != INVALID_ENTITY_ID
    destroyEntity(human_parachute_anim__currentEffect)


[es(tag=gameClient, track=human_parachute_anim__currentState)]
def parachute_effect_destroy_on_closing(evt : Event;
                                        eid : EntityId;
                                        human_parachute_anim__currentState : int;
                                        human_parachute__eid : EntityId;
                                        human_parachute_effect__attachedTo : EntityId)
  if human_parachute_anim__currentState == int(ParachuteState.CLOSED)
    query(human_parachute_effect__attachedTo) <| $ [es] (var human_parachute_effect__eid : EntityId&)
      human_parachute_effect__eid = INVALID_ENTITY_ID
    destroyEntity(human_parachute__eid)
    destroyEntity(eid)


[es(tag=gameClient, on_appear)]
def parachute_init_animation(evt : Event;
                             var animchar : AnimcharBaseComponent&;
                             parachute_anim__closedState : string;
                             parachute_anim__openedState : string;
                             parachute_anim__closingState : string;
                             parachute_anim__openingState : string;
                             var parachute_anim__closedStateId : int&;
                             var parachute_anim__openedStateId : int&;
                             var parachute_anim__closingStateId : int&;
                             var parachute_anim__openingStateId : int&)
  assume animGraph = animchar.animGraph
  if animGraph != null
    parachute_anim__closedStateId = anim_graph_getStateIdx(*animGraph, parachute_anim__closedState)
    parachute_anim__openedStateId = anim_graph_getStateIdx(*animGraph, parachute_anim__openedState)
    parachute_anim__closingStateId = anim_graph_getStateIdx(*animGraph, parachute_anim__closingState)
    parachute_anim__openingStateId = anim_graph_getStateIdx(*animGraph, parachute_anim__openingState)

  if parachute_anim__closedStateId < 0
    logerr("Couldn't find parachute closed state animation!")
  if parachute_anim__openedStateId < 0
    logerr("Couldn't find parachute opened state animation!")
  if parachute_anim__closingStateId < 0
    logerr("Couldn't find parachute closing state animation!")
  if parachute_anim__openingStateId < 0
    logerr("Couldn't find parachute opening state animation!")


[es(tag=gameClient, after=human_anim_es)]
def parachute_animation_continuous(info : ParallelUpdateFrameDelayed;
                                   var animchar : AnimcharBaseComponent&;
                                   var parachute_anim__lastDeployState : bool&;
                                   var parachute_anim__openedAtTime : float&;
                                   var parachute_anim__closedAtTime : float&;
                                   parachute_anim__openDuration : float;
                                   parachute_anim__closeDuration : float;
                                   parachute_anim__closedStateId : int;
                                   parachute_anim__openedStateId : int;
                                   parachute_anim__closingStateId : int;
                                   parachute_anim__openingStateId : int;
                                   parachute_anim__isOpened : bool)
  assume animGraph = animchar.animGraph
  if animGraph == null
    return

  // Feels like tracked should be used for this, but tracked es's are triggered at the end of the frame
  // Because of this current es will always be executed once before any track es
  // And unless we set openedAtTime and closedAtTime before that, one frame of already opened parachute
  // would play and it looked horrible
  if parachute_anim__lastDeployState != parachute_anim__isOpened
    if parachute_anim__isOpened && parachute_anim__openedAtTime == 0.0
      parachute_anim__openedAtTime = info.curTime
    elif !parachute_anim__isOpened && parachute_anim__closedAtTime == 0.0
      parachute_anim__closedAtTime = info.curTime
    parachute_anim__lastDeployState = parachute_anim__isOpened

  if parachute_anim__isOpened
    if info.curTime < parachute_anim__openedAtTime + parachute_anim__openDuration
      *animGraph |> anim_graph_enqueueState(*animchar.animState, parachute_anim__openingStateId)
    else
      *animGraph |> anim_graph_enqueueState(*animchar.animState, parachute_anim__openedStateId)
  else
    if info.curTime < parachute_anim__closedAtTime + parachute_anim__closeDuration
      *animGraph |> anim_graph_enqueueState(*animchar.animState, parachute_anim__closingStateId)
    else
      *animGraph |> anim_graph_enqueueState(*animchar.animState, parachute_anim__closedStateId)
