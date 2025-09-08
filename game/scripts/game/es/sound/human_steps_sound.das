require ecs
require ecs.safe
require soundHash
require soundSystem
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require danetlibs.renderer.includes.pufd_events
require common_sounds.modules.common_sounds_events
require human_sounds.modules.human_steps_sound_common
require DngHuman
require game.utils.hero
require game.utils.team
require DagorMath
require strings
require DngNet


[es(tag=sound, after=(human_sound_landmesh_queries_update, sound_begin_update_es), before=(human_steps_sound_update, sound_end_update_es))]
def human_steps_sound_states_from_human_net_phys(info : ParallelUpdateFrameDelayed;
                                                 human_net_phys : HumanActor;
                                                 animchar__animSpeed : float;
                                                 var human_steps_sound__moveState : int&;
                                                 var human_steps_sound__animSpeed : float&)

  human_steps_sound__moveState = int(human_net_phys.phys.currentState.moveState)
  human_steps_sound__animSpeed = animchar__animSpeed


def human_steps_sound_states_from_human_navmesh_phys_impl(speed : float;
                                                          navmesh_phys__walkSpeedModifier = 0.5;
                                                          var human_steps_sound__moveState : int&;
                                                          var human_steps_sound__animSpeed : float&)
  // navmesh_move_anim es related
  human_steps_sound__animSpeed = speed
  if speed > navmesh_phys__walkSpeedModifier * 1.1
    human_steps_sound__moveState = int(HUMoveState.EMS_RUN)
  elif speed > FLT_EPSILON
    human_steps_sound__moveState = int(HUMoveState.EMS_WALK)
  else
    human_steps_sound__moveState = int(HUMoveState.EMS_STAND)


[es(tag=sound, REQUIRE_NOT=(human_net_phys, human_net_phys, loc_snapshots__snapshotData), after=sound_begin_update_es, before=human_steps_sound_update)]
def human_steps_sound_states_from_human_navmesh_phys_offline(info : ParallelUpdateFrameDelayed;
                                                             navmesh_phys__currentWalkVelocity : float3;
                                                             navmesh_phys__walkSpeedModifier = 0.5;
                                                             var human_steps_sound__moveState : int&;
                                                             var human_steps_sound__animSpeed : float&)
  // navmesh_move_anim es related
  let speed = length(navmesh_phys__currentWalkVelocity)
  human_steps_sound_states_from_human_navmesh_phys_impl(speed, navmesh_phys__walkSpeedModifier, human_steps_sound__moveState, human_steps_sound__animSpeed)


[es(tag=sound, REQUIRE_NOT=human_net_phys, after=sound_begin_update_es, before=human_steps_sound_update)]
def human_steps_sound_states_from_human_navmesh_phys_online(info : ParallelUpdateFrameDelayed;
                                                            loc_snapshots__snapshotData : LocSnapshotsList;
                                                            navmesh_phys__walkSpeedModifier = 0.5;
                                                            var human_steps_sound__moveState : int&;
                                                            var human_steps_sound__animSpeed : float&)
  // navmesh_move_anim es related
  var speed = 0.
  let n = length(loc_snapshots__snapshotData)
  if n >= 2
    let begin = loc_snapshots__snapshotData[0].pos
    let end = loc_snapshots__snapshotData[n - 1].pos
    let time = loc_snapshots__snapshotData[n - 1].atTime - loc_snapshots__snapshotData[0].atTime
    let vel = (end - begin) / time
    speed = length(vel)
  human_steps_sound_states_from_human_navmesh_phys_impl(speed, navmesh_phys__walkSpeedModifier, human_steps_sound__moveState, human_steps_sound__animSpeed)


[es(tag=sound, after=(human_sound_landmesh_queries_update, sound_begin_update_es), before=sound_end_update_es)]
def human_steps_sound_update(info : ParallelUpdateFrameDelayed)

  let listenerPos = get_listener_pos()

  query() <| $ [es(REQUIRE_NOT=deadEntity)] (eid : EntityId;
                                             sound_control__state : int = default_sound_control_state();

                                             transform : float3x4;
                                             is_watched_sound : bool;

                                             human_net_phys__states : int = int(StateFlag.ST_ON_GROUND);
                                             human_net_phys__isClimbing : bool = false;
                                             var human_net_phys : HumanActor?;

                                             animchar__animSpeed : float;
                                             animchar__updatable : bool;
                                             animchar__visible : bool;

                                             human_steps_sound__moveState : int;
                                             human_steps_sound__animSpeed : float;
                                             human_steps_sound__animSpeedMul : float;
                                             human_steps_sound__farawayThresholdSq : float;
                                             @shared_comp human_steps_sound__irqs : Array;

                                             var human_steps_sound__irqObjIdx : int&;
                                             var human_steps_sound__physStates : int&;
                                             var human_steps_sound__lastTimeOnGround : float&;

                                             var human_sound_landmesh_queries_vars__speedSq : float&;
                                             var human_sound_landmesh_queries_vars__isOnGround : bool&;

                                             var human_steps_sound_generator__lastStepAt_cooldown : float2&;
                                             human_steps_sound_generator__walkRunSprint_stand_intervals : float3;
                                             human_steps_sound_generator__walkRunSprint_crouch_intervals : float3;
                                             human_steps_sound_generator__enableForVisible : bool;
                                             human_steps_sound_generator__enableForInvisible : bool;
                                             human_steps_sound_generator__enableAlways : bool)

    if !have_sound(sound_control__state) || is_faraway_step(is_watched_sound, transform[3], human_steps_sound__farawayThresholdSq, listenerPos)
      human_sound_landmesh_queries_vars__speedSq = 0.
      human_sound_landmesh_queries_vars__isOnGround = true
      human_steps_sound__physStates = human_net_phys__states
      human_steps_sound__irqObjIdx = INVALID_IRQ_OBJ_IDX
      return

    var standState = HUStandState.ESS_STAND
    var moveState = human_steps_sound__moveState
    var animSpeed = human_steps_sound__animSpeed
    if human_net_phys != null
      standState = human_net_phys.phys.currentState.standState
      moveState = int(human_net_phys.phys.currentState.moveState)
      animSpeed = animchar__animSpeed

    let irqObjIdx = human_steps_sound_generate(human_steps_sound__irqObjIdx,
                                               info.curTime,
                                               info.dt,
                                               read_state(StateFlag.ST_ON_GROUND, human_net_phys__states),
                                               human_net_phys__isClimbing,
                                               moveState,
                                               standState,
                                               animSpeed * human_steps_sound__animSpeedMul,
                                               animchar__updatable,
                                               animchar__visible,
                                               human_steps_sound_generator__lastStepAt_cooldown,
                                               human_steps_sound_generator__walkRunSprint_stand_intervals,
                                               human_steps_sound_generator__walkRunSprint_crouch_intervals,
                                               human_steps_sound_generator__enableForVisible,
                                               human_steps_sound_generator__enableForInvisible,
                                               human_steps_sound_generator__enableAlways,
                                               human_steps_sound__irqs)

    human_steps_sound__irqObjIdx = INVALID_IRQ_OBJ_IDX
    human_sound_landmesh_queries_vars__speedSq = human_net_phys != null ? length_sq((*human_net_phys).phys.currentState.velocity.xz) : 0.
    human_sound_landmesh_queries_vars__isOnGround = read_state(StateFlag.ST_ON_GROUND, human_net_phys__states)

    let descId = human_steps_sound_update_states(info.curTime,
                                                 human_net_phys__states,
                                                 human_steps_sound__physStates,
                                                 human_steps_sound__lastTimeOnGround)

    if irqObjIdx == INVALID_IRQ_OBJ_IDX && empty(descId)
      return

    query(eid) <| $ [es] (sound_tags : Object;
                          team : int;
                          var sound_event_group : SoundEventGroup&;
                          human_steps_sound__traceStepOffsetLen : float2;
                          human_steps_sound__friendVolume : float;
                          human_steps_sound__enemyVolume = 1.;

                          @shared_comp human_steps_sound__path : Object;
                          @shared_comp human_steps_sound__descs : Object;
                          @shared_comp human_steps_sound__irqs : Array;
                          @shared_comp human_steps_sound__stepFx : Object;

                          var human_steps_sound__waterDepth : float&;
                          var human_steps_sound__smid : float&;
                          var human_steps_sound__stepIdx : uint&;

                          human_sound_landmesh_queries__biomePhysMatId : int;
                          human_sound_landmesh_queries__biomeOverridesWater : bool;
                          human_sound_landmesh_queries__puddleDepth : float)

      var desc : Object const? = null
      var shouldTraceEnemy = false
      if !empty(descId)
        desc = sound_player_common::get_desc(human_steps_sound__descs, descId)
        shouldTraceEnemy = false
      elif irqObjIdx != INVALID_IRQ_OBJ_IDX
        desc = human_steps_sound__irqs?[irqObjIdx] ?as Object
        shouldTraceEnemy = (human_steps_sound__stepIdx & 1u) != 0u
        ++human_steps_sound__stepIdx

        if (human_steps_sound__stepIdx & 3u) == 0u && desc != null
          let stepFxPath = human_steps_sound__stepFx[desc.name ?? ""] ?as Object
          if stepFxPath != null
            sound_player_common::play_path(*stepFxPath, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group)

      if desc != null
        let volume = (is_watched_sound ? 1. : is_teams_friendly(team, (get_int(get_controlled_hero(), "team") ?? TEAM_UNASSIGNED)) ? human_steps_sound__friendVolume : human_steps_sound__enemyVolume)
        play_footstep(*desc,
                      human_steps_sound__path,
                      sound_tags,
                      volume,
                      eid,
                      transform[3],
                      shouldTraceEnemy,
                      is_watched_sound,
                      human_steps_sound__traceStepOffsetLen,
                      human_sound_landmesh_queries__biomePhysMatId,
                      human_sound_landmesh_queries__biomeOverridesWater,
                      human_sound_landmesh_queries__puddleDepth,
                      standState,
                      human_steps_sound__smid,
                      human_steps_sound__waterDepth,
                      human_net_phys)


[es(tag=sound, REQUIRE_NOT=deadEntity)]
def human_steps_sound_irq(evt : CmdSoundStepIrq;
                          var human_steps_sound__irqObjIdx : int&)
  human_steps_sound__irqObjIdx = evt.objIdx


[es(tag=sound, on_appear)]
def human_steps_sound_on_appear(evt : Event;
                                human_steps_sound__tag : string;
                                var sound_flags : Object&)
  raise_sound_tag(human_steps_sound__tag, sound_flags)
