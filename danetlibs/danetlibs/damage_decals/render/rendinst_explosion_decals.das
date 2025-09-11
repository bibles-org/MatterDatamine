require ecs
require math.base
require Dacoll
require DamageDecals
require DngDm
require danetlibs.weapons.shell_events


// Perform additional traces to fix cases like this
//             |wall                ^ decal
//             |                    | normal
//             |                   _|______________
//    decal  ^ |       or this    |            roof
//    normal | |                  |
// __________|_|                  |wall
// floor
//
// They are bad because we can't project decal on perpendicular surfaces, but we can tweak
// normal, so the decal will be projected on both the floor and the wall at once.
def adjust_decal_normal_by_side_traces(decal_pos : float3; decal_normal : float3; side_trace_length : float;
                                       var out_normal : float3&)
  let expectedTraceDistance = side_trace_length / 3f
  let traceFrom = decal_pos + decal_normal * expectedTraceDistance
  let traceDistanceThreshold = expectedTraceDistance * 0.5f
  let normalDotThreshold = 0.2

  out_normal = decal_normal
  let mainDir = -decal_normal
  let tang = normalize(abs(mainDir.x) < 0.9f ? cross(mainDir, float3(1, 0, 0)) : cross(mainDir, float3(0, 1, 0)))
  let bitang = cross(mainDir, tang)
  let sideVectors = fixed_array(tang, -tang, bitang, -bitang)

  let M_SQRT1_2 = 0.70710678
  var skipNextTrace = false
  for sideVec, i in sideVectors, count()
    if skipNextTrace
      skipNextTrace = false
      continue
    let traceDir = (mainDir + sideVec) * M_SQRT1_2
    var t = side_trace_length
    var norm : float3
    if !traceray_normalized(traceFrom, traceDir, t, norm, ETF_DEFAULT)
      t = FLT_MAX
    let surfaceDiff = expectedTraceDistance - t * M_SQRT1_2;
    if abs(surfaceDiff) > traceDistanceThreshold  // We either hit nearest wall or trace is missed.
      out_normal += surfaceDiff < 0f ? sideVec : -sideVec
      if i == 0 || i == 2
        // Ignore trace with opposite side vector if we already somehow tweaked the normal.
        // It prevents normal from resetting to original direction when both traces hit the wall or both are missed.
        skipNextTrace = true
    elif dot(decal_normal, norm) < normalDotThreshold
      // If trace hit somewhere in plane of decal, but surface normal differs too much
      // we still can use this normal to tweak our decal
      out_normal += norm
  out_normal = normalize(out_normal);

def trace_and_spawn_explosion_decal(pos : float3; dir : float3;
                                    trace_offset, trace_len, side_trace_len : float;
                                    decal_size : float; damage_type : string)
  var t = trace_len
  let traceFrom = pos - trace_offset * dir
  var norm : float3
  var pmid : int
  var riDesc = RendInstDesc()
  if traceray_normalized(traceFrom, dir, t, pmid, norm, ETF_DEFAULT | ETF_RI_PHYS, riDesc, -1)
    let decalDir = -norm
    let decalPos = traceFrom + t * dir
    if side_trace_len > 0f
      adjust_decal_normal_by_side_traces(decalPos, norm, side_trace_len, norm)
    create_ri_projective_damage_decal(decalPos, decalDir, norm, riDesc.riExtraHandle, decal_size, pmid, damage_type)

[es(tag=render, REQUIRE=msg_sink)]
def rendinst_explosion_decal(evt : CmdShellExplodeClient)
  query(evt.fxInfoEid) <| $[es] (shell_explosion_decal__damageType : string;
                                 shell_explosion_decal__size : float;
                                 shell_explosion_decal__traceShootDir : bool;
                                 shell_explosion_decal__traceOffset : float;
                                 shell_explosion_decal__traceLength : float;
                                 shell_explosion_decal__sideTraceLength : float)
    let traceDir = shell_explosion_decal__traceShootDir ? normalize_default(evt.shellVelocity, float3(0, -1, 0)) : float3(0, -1, 0)
    if shell_explosion_decal__damageType == "bomb_explosion"
      query() <| $[es] (eid : EntityId;
                        ri_bomb_hit_decal__id : int;
                        ri_bomb_hit_decal__pos : float3)
        if length(ri_bomb_hit_decal__pos - evt.pos) < shell_explosion_decal__size
          remove_ri_damage_decal(ri_bomb_hit_decal__id)
          destroyEntity(eid)
    trace_and_spawn_explosion_decal(evt.pos, traceDir, shell_explosion_decal__traceOffset,
      shell_explosion_decal__traceLength, shell_explosion_decal__sideTraceLength,
      shell_explosion_decal__size, shell_explosion_decal__damageType)
