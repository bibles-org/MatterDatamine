require ecs
require math.random
require Dacoll
require DagorMath
require DamageDecals
require DngDm
require RendInst
require PhysMat
require danetlibs.weapons.shell_events
require danetlibs.damage_decals.damage_decals_events


def random_direction_in_hemisphere()
  let phi = rnd_float(0.f, 2.f * PI)
  let theta = acos(rnd_float(0.f, 1.f))
  let dir = float3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
  return dir

[es(tag=render, on_event=ParallelUpdateFrameDelayed, after=after_net_phys_sync)]
def process_shatter_decal_traces(evt : Event;
                                 ri_shatter_decals__traceCountPerFrame : int;
                                 ri_shatter_decals__minTraceDistance : float;
                                 var ri_shatter_decals__traceFrom : Point3List?;
                                 var ri_shatter_decals__traceTo : Point3List?;
                                 var ri_shatter_decals__traceHit : UInt8List?)
  var tracesLeft = ri_shatter_decals__traceCountPerFrame
  find_query() <| $[es] (eid : EntityId;
                         ri_shatter_decals__explosionPos : float3;
                         ri_shatter_decals__traceLen : float;
                         var ri_shatter_decals__traceCount : int&)
    if ri_shatter_decals__traceCount <= 0
      destroyEntity(eid)
      return false
    let numTraces = min(tracesLeft, ri_shatter_decals__traceCount)
    tracesLeft -= numTraces
    ri_shatter_decals__traceCount -= numTraces
    for _ in range(numTraces)
      let dir = random_direction_in_hemisphere()
      var pmid = -1
      var norm = float3()
      var t = ri_shatter_decals__traceLen
      var riDesc = RendInstDesc()
      var traceHit = false
      if traceray_normalized(ri_shatter_decals__explosionPos, dir, t, pmid, norm, ETF_LMESH | ETF_HEIGHTMAP | ETF_FRT | ETF_RI | ETF_STRUCTURES, riDesc, -1)
        traceHit = t > ri_shatter_decals__minTraceDistance
      let pos = ri_shatter_decals__explosionPos + dir * t
      if traceHit
        // We can create decals only in main thread, so send deferred event instead
        broadcastEvent(CmdRendinstShatterDecal(pos = pos, norm = norm, pmid = pmid, riexHandle = riDesc.riExtraHandle))
      if ri_shatter_decals__traceFrom != null && ri_shatter_decals__traceTo != null && ri_shatter_decals__traceHit != null
        push(*ri_shatter_decals__traceFrom, ri_shatter_decals__explosionPos)
        push(*ri_shatter_decals__traceTo, pos)
        push(*ri_shatter_decals__traceHit, traceHit ? 1u8 : 0u8)
    return tracesLeft == 0

def convert_value_from_table(value : float; cvt_table : Point2List)
  if empty(cvt_table)
    return value
  var valueToRes0 = cvt_table[0]
  for valueToRes1 in cvt_table
    if value <= valueToRes1.x
      return cvt(value, valueToRes0.x, valueToRes1.x, valueToRes0.y, valueToRes1.y)
    valueToRes0 = valueToRes1
  return valueToRes0.y

[es(tag=render, REQUIRE=msg_sink)]
def rendinst_shatter_decals_on_explosion(evt : CmdShellExplodeClient)
  query() <| $[es] (ri_shatter_decals__maxRadiusToTraceLen : Point2List;
                    ri_shatter_decals__maxRadiusToTraceCount : Point2List)
    let explosionPos = evt.offsetedPos
    let maxRadius =  get_shell_max_radius(int(evt.shellId.shellId), int(evt.shellId.damageId), int(evt.shellId.ballisticsId))
    let traceLen = convert_value_from_table(maxRadius, ri_shatter_decals__maxRadiusToTraceLen)
    let numTraces = int(convert_value_from_table(maxRadius, ri_shatter_decals__maxRadiusToTraceCount))
    createEntity("rendinst_shatter_decals_tracer") <| $(var init : ComponentsInitializer)
      set(init, "ri_shatter_decals__traceCount", numTraces)
      set(init, "ri_shatter_decals__traceLen", traceLen)
      set(init, "ri_shatter_decals__explosionPos", explosionPos)

[es(tag=render)]
def create_shatter_decal_on_ri(evt : CmdRendinstShatterDecal)
  let SHATTERS_DECAL_SIZE = 0.5f
  let dir = -evt.norm
  if evt.pmid != int(PHYSMAT_INVALID)
    create_ri_projective_damage_decal(evt.pos, dir, evt.norm, evt.riexHandle, SHATTERS_DECAL_SIZE, evt.pmid, "shrapnel_damage")
