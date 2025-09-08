module human_steps_sound_common shared

require ecs
require ecs.safe

require math
require math.base
require DagorMath

require PhysMat
require HumanPhys
require DngHuman
require Dacoll
require GridCollision
require CollisionTraces
require DagorSystem

require soundEvent
require soundSystem
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_physmat_common


let INVALID_IRQ_OBJ_IDX = -1


def is_faraway_step(is_watched : bool; pos : float3; max_distance_sq : float; listener_pos : float3) : bool
  return !is_watched && distance_sq(listener_pos, pos) > max_distance_sq


def read_state(state_flag : StateFlag; states : int) : bool
  return (states & int(state_flag)) != 0


def private is_on_lmesh(pos : float3; stand_state : HUStandState)
  let posXZ = pos.xz
  let ground = traceht_lmesh(posXZ)
  let threshold = stand_state == HUStandState.ESS_CRAWL ? 0.2 :  0.1
  return pos.y < ground + threshold



def trace_footstep(human_eid : EntityId;
                   pos : float3;
                   should_trace_enemy : bool;
                   is_watched_sound : bool;
                   trace_offset_len : float2;
                   biome_pmid : int;
                   biome_overrides_water : bool;
                   puddle_depth : float;
                   stand_state : HUStandState;
                   var step_material_id : float&;
                   var step_water_depth : float&;
                   var human_net_phys : HumanActor?)

  if human_net_phys == null
    // TODO: trace without human_net_phys
    step_water_depth = 0.
    step_material_id = get_sound_step_material_id(get_material_id("default"))
    return

  if !is_watched_sound && !should_trace_enemy
    return

  var pmid = PHYSMAT_INVALID
  let from = float3(pos.x, pos.y + trace_offset_len.x, pos.z)
  var len = trace_offset_len.y
  if !tracedown_normalized(from, len, pmid, ETF_DEFAULT, (*human_net_phys).phys |> human_phys_getTraceHandle())
    len = trace_offset_len.y
    pmid = PHYSMAT_INVALID

  trace_entities_in_grid(ecs_hash("vehicles"), from, float3(0., -1., 0.), len, human_eid, SortIntersections.NO) <| $(intersections : array<IntersectedEntity>#)
    for it in intersections
      if it.t < len + FLT_EPSILON
        len = it.t
        pmid = PHYSMAT_INVALID
        query(it.eid) <| $ [es] (material : string)
          pmid = get_material_id(material)

  step_water_depth = 0.
  var water = 0.
  if traceht_water(from, water) && pos.y < water
    let posXZ = pos.xz
    let ground = traceht_lmesh(posXZ)
    let floor = max(from.y - len, ground)
    step_water_depth = max(0., water - floor)

  let isOnLMesh = is_on_lmesh(pos, stand_state)
  let waterDepth = isOnLMesh ? max(step_water_depth, puddle_depth) : step_water_depth
  let isInWater = waterDepth > 0.
  if isOnLMesh && biome_pmid != PHYSMAT_INVALID && (!isInWater || biome_overrides_water)
    pmid = biome_pmid
  elif isInWater
    pmid = get_material_id("water")

  step_material_id = get_sound_step_material_id(pmid)


def private raise_pos_above_collision(pos : float3) // need pos above collision to make proper occlusion tests
  // TODO: find better, correct offsets, e.g. from pelvis
  return pos + float3(0., 0.5, 0.)


def play_footstep(desc : Object;
                  path : Object;
                  sound_tags : Object;
                  volume : float;

                  human_eid : EntityId;
                  pos : float3;
                  should_trace_enemy : bool;
                  is_watched_sound : bool;
                  trace_offset_len : float2;
                  biome_pmid : int;
                  biome_overrides_water : bool;
                  puddle_depth : float;
                  stand_state : HUStandState;
                  var step_material_id : float&;
                  var step_water_depth : float&;
                  var human_net_phys : HumanActor?;
                  prefix : string = "")

  trace_footstep(human_eid,
                 pos,
                 should_trace_enemy,
                 is_watched_sound,
                 trace_offset_len,
                 biome_pmid,
                 biome_overrides_water,
                 puddle_depth,
                 stand_state,
                 step_material_id,
                 step_water_depth,
                 human_net_phys)

  if step_material_id >= 0.
    var pathStr : string
    if sound_player_common::get_option_path(path, sound_tags, is_watched_sound, pathStr)
      let offsetedPos = raise_pos_above_collision(pos)
      let soundPath = apply_watched_prefix(pathStr, is_watched_sound)
      var handle = sound_player_common::play_desc_path(desc, "{prefix}{soundPath}", is_watched_sound, offsetedPos, false)
      if step_water_depth > 0.
        set_var(handle, "depth", step_water_depth)
      if read_sound_tag("armored", sound_tags)
        set_var(handle, "armored", 1.)
      set_volume(handle, volume)
      set_var(handle, "mat", step_material_id)
      abandon(handle)


def get_desc_id_from_human_state(move_state : int; stand_state : HUStandState; irqs : Array) : int

  let name = ((stand_state == HUStandState.ESS_CROUCH) ? "step" :
             (stand_state == HUStandState.ESS_CRAWL) ? "crawl" :
             (move_state == int(HUMoveState.EMS_SPRINT)) ? "sprint" :
             (move_state == int(HUMoveState.EMS_RUN)) ? "run" :
             "step")

  for it, idx in irqs, range(length(irqs))
    if ((it as Object)?.name ?? "") == name
      return idx

  sound_debug("desc with name {name} not in irqs")

  return INVALID_IRQ_OBJ_IDX



def use_generator(enable_for_visible, enable_for_invisible, updatable, visible : bool; move_state : int; stand_state : HUStandState)

  if move_state == int(HUMoveState.EMS_ROTATE_LEFT) || move_state == int(HUMoveState.EMS_ROTATE_RIGHT) || stand_state == HUStandState.ESS_CRAWL
    return false

  if (!updatable || !visible) && enable_for_invisible
    return true

  return (move_state == int(HUMoveState.EMS_SPRINT) || move_state == int(HUMoveState.EMS_RUN)) && enable_for_visible



def human_steps_sound_generate(irq_obj_idx : int;
                               cur_time : float;
                               dt : float;

                               is_on_ground : bool;
                               is_climbing : bool;
                               move_state : int;
                               stand_state : HUStandState;

                               animchar__animSpeed : float;
                               animchar__updatable : bool;
                               animchar__visible : bool;

                               var lastStepAt_cooldown : float2&;

                               walkRunSprint_stand_intervals : float3;
                               walkRunSprint_crouch_intervals : float3;

                               enable_for_visible : bool;
                               enable_for_invisible : bool;
                               enable_always : bool;

                               @shared_comp irqs : Array) : int

  assume last_step_at = lastStepAt_cooldown.x
  assume cooldown = lastStepAt_cooldown.y

  let useGenerator = (enable_always || use_generator(enable_for_visible, enable_for_invisible, animchar__updatable, animchar__visible, move_state, stand_state)) && animchar__animSpeed > VERY_SMALL_NUMBER

  if move_state == int(HUMoveState.EMS_STAND) || stand_state == HUStandState.ESS_DOWNED || !is_on_ground || is_climbing
    cooldown = min(cooldown + dt, 1.)
    return INVALID_IRQ_OBJ_IDX

  cooldown = max(0., cooldown - dt)

  if irq_obj_idx == INVALID_IRQ_OBJ_IDX && !useGenerator
    return INVALID_IRQ_OBJ_IDX

  if useGenerator

    assume stand_intervals = walkRunSprint_stand_intervals
    assume crouch_intervals = walkRunSprint_crouch_intervals
    //stand_intervals = float3(1.15, 0.85, 1.65) // debug find proper values manually using app.timeSpeed 0.25

    let intervals = (stand_state == HUStandState.ESS_CROUCH ? crouch_intervals : stand_intervals)
    let interval = (move_state == int(HUMoveState.EMS_SPRINT)) ? intervals.z : (move_state == int(HUMoveState.EMS_RUN)) ? intervals.y : intervals.x
    let step = safediv(interval, animchar__animSpeed)
    cooldown = min(cooldown, step * 0.5)

    if cur_time >= last_step_at + step
      last_step_at = cur_time
      if cooldown != 0.
        return INVALID_IRQ_OBJ_IDX
      //logerr("[GENERATOR] move_state={move_state}  stand_state={stand_state} interval={interval} animSpeed={animchar__animSpeed} curTime={cur_time}")
      return get_desc_id_from_human_state(move_state, stand_state, irqs)

  elif irq_obj_idx != INVALID_IRQ_OBJ_IDX

    let irqCooldown = 0.2
    if (cur_time - last_step_at) * animchar__animSpeed >= irqCooldown
      last_step_at = cur_time
      //logerr("[IRQ] stepDt={cur_time - last_step_at} animSpeed={animchar__animSpeed} move_state={move_state}  stand_state={stand_state}")
      return irq_obj_idx

  return INVALID_IRQ_OBJ_IDX


def human_steps_sound_update_states(cur_time : float;
                                    human_net_phys__states : int;
                                    var human_steps_sound__physStates : int&;
                                    var human_steps_sound__lastTimeOnGround : float&) : string

  if human_steps_sound__physStates < 0
    human_steps_sound__physStates = human_net_phys__states
  let raisedStates = human_net_phys__states & ~human_steps_sound__physStates
  let clearedStates = human_steps_sound__physStates & ~human_net_phys__states
  human_steps_sound__physStates = human_net_phys__states

  if (raisedStates | clearedStates) != 0

    if read_state(StateFlag.ST_ON_GROUND, clearedStates)
      human_steps_sound__lastTimeOnGround = cur_time

    if read_state(StateFlag.ST_JUMP, raisedStates)
      return "jump"

    elif read_state(StateFlag.ST_ON_GROUND, raisedStates)
      return "land"

    elif read_state(StateFlag.ST_SWIM, raisedStates)
      if !read_state(StateFlag.ST_ON_GROUND, human_net_phys__states)
        return "land"
    elif read_state(StateFlag.ST_CROUCH, raisedStates)
      return "downKnee"
    elif read_state(StateFlag.ST_CROUCH, clearedStates)
      return "upKnee"
    elif read_state(StateFlag.ST_DOWNED, raisedStates)
      return "downKnee"
    elif read_state(StateFlag.ST_DOWNED, clearedStates)
      return "upKnee"
    elif read_state(StateFlag.ST_CRAWL, raisedStates)
      return "downGround"
    elif read_state(StateFlag.ST_CRAWL, clearedStates)
      return "upGround"

  return ""
