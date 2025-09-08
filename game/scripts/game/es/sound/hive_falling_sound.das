require ecs
require app
require game.events.events_active_matter
require soundEvent
require DagorMath
require PhysMat
require Dacoll


[es(tag=sound, on_appear)]
def hive_falling_sound_on_appear(evt : Event;
                                 var hive_falling_sound__hitPt : float3&;
                                 var hive_falling_sound__playAtTime : float&;
                                 hive_falling_sound__maxTraceLen : float;
                                 hive_falling_sound__delayMul : float;
                                 transform : float3x4)

  let dir = float3(0., -1., 0.)
  var t = hive_falling_sound__maxTraceLen
  var norm : float3
  var matId = PHYSMAT_INVALID
  var riDesc = RendInstDesc()

  hive_falling_sound__playAtTime = -1.
  if traceray_normalized(transform[3], dir, t, matId, norm, ETF_DEFAULT, riDesc, -1)
    hive_falling_sound__hitPt = transform[3] + dir * t
    let delay = sqrt((2. * max(t, 0.1)) * 0.1) * hive_falling_sound__delayMul
    hive_falling_sound__playAtTime = get_sync_time() + delay


[es(tag=sound)]
def hive_falling_sound_update(evt : ParallelUpdateFrameDelayed;
                              eid : EntityId;
                              hive_falling_sound__path : string;
                              hive_falling_sound__hitPt : float3;
                              var hive_falling_sound__playAtTime : float&)

  if evt.curTime >= hive_falling_sound__playAtTime
    if hive_falling_sound__playAtTime >= 0.
      oneshot(hive_falling_sound__path, hive_falling_sound__hitPt)
    hive_falling_sound__playAtTime = -1.
    destroyEntity(eid)
