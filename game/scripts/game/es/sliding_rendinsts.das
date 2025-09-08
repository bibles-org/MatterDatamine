require ecs
require ecs.safe
require math.easing
require math.base
require DagorMath
require game.events.events_game
require game.events.events_active_matter
require RendInst
require RendInstPhys
require Dacoll


[es(track=sliding_rendinst__slidedState)]
def sliding_rendinst_track_state(evt : Event;
                                 eid aka sliding_rendinst_eid : EntityId;
                                 sliding_rendinst__progress : float;
                                 sliding_rendinst__slidedState : bool;
                                 sliding_rendinst__offset : float;
                                 sliding_rendinst__metersPerSecond : float;
                                 sliding_rendinst__movingTemplate : string;
                                 sliding_rendinst_moving : Tag const?)
  if sliding_rendinst_moving == null
    let requiredProgress = sliding_rendinst__slidedState ? 1.0 : 0.0
    if is_equal_float(sliding_rendinst__progress, requiredProgress)
      return

    addSubTemplate(sliding_rendinst_eid, sliding_rendinst__movingTemplate) <| $ [es] (var init : ComponentsInitializer)
      init |> set("sliding_rendinst_moving__progressSpeed", safediv(sliding_rendinst__metersPerSecond, sliding_rendinst__offset))


[es(no_order)]
def sliding_rendinst_moving(act : ParallelUpdateFrameDelayed;
                            eid aka sliding_rendinst_eid : EntityId;
                            sliding_rendinst__axis : float3;
                            sliding_rendinst__offset : float;
                            sliding_rendinst_moving__progressSpeed : float;
                            sliding_rendinst__movingTemplate : string;
                            sliding_rendinst__smoothProgress : bool;
                            sliding_rendinst__pauseOnCollision : bool;
                            sliding_rendinst__slideOnCollision : Tag const?;
                            initialTransform : float3x4;
                            ri_extra : RiExtraComponent;
                            var sliding_rendinst__slidedState : bool&;
                            var transform : float3x4;
                            var sliding_rendinst__progress : float&)
  var finished = false

  var newProgress = sliding_rendinst__progress
  if sliding_rendinst__slidedState
    newProgress += sliding_rendinst_moving__progressSpeed * act.dt
    if newProgress >= 1.0
      newProgress = 1.0
      finished = true
  else
    newProgress -= sliding_rendinst_moving__progressSpeed * act.dt
    if newProgress <= 0.0
      newProgress = 0.0
      finished = true

  let progress = sliding_rendinst__smoothProgress ? inOutBezier(inOutBezier(newProgress)) : newProgress
  let currentOffsetValue = sliding_rendinst__offset * progress
  let currentOffset = rotate(initialTransform, sliding_rendinst__axis) * currentOffsetValue


  if sliding_rendinst__pauseOnCollision
    var pause = false
    var checkTransform = initialTransform
    checkTransform[3] += rotate(initialTransform, sliding_rendinst__axis) * (currentOffsetValue + sign(newProgress - sliding_rendinst__progress))

    using(ri_extra.handle) <| $(var desc : RendInstDesc#)
      if check_ri_collision_filtered(desc, transform, checkTransform, (int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_KINEMATIC)))
        pause = true
        return
    if pause
      return
  elif sliding_rendinst__slideOnCollision != null
    var checkTransform = initialTransform
    checkTransform[3] += rotate(initialTransform, sliding_rendinst__axis) * (currentOffsetValue + sign(newProgress - sliding_rendinst__progress))

    using(ri_extra.handle) <| $(var desc : RendInstDesc#)
      if check_ri_collision_filtered(desc, transform, checkTransform, (int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_KINEMATIC)))
        sliding_rendinst__slidedState = true
        return

  sliding_rendinst__progress = newProgress
  transform = initialTransform
  transform[3] += currentOffset

  if finished
    removeSubTemplate(sliding_rendinst_eid, sliding_rendinst__movingTemplate)