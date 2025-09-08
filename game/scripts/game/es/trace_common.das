module trace_common shared
require ecs
require Grid
require CollisionTraces
require GridCollision
require DagorMath
require DagorSystem
require RendInst
require Dacoll
require CollRes
require PhysMat


def private trace_traceable_sphere(from : float3;
                                   dir : float3;
                                   sphere_eid : EntityId;
                                   sphere_pos : float3;
                                   sphere_radius : float;
                                   var t : float&;
                                   var intersections : IntersectedEntities | #)
  let dist = rayIntersectSphereDist(from, dir, sphere_pos, sphere_radius)
  if dist >= 0.0 && dist <= t
    t = dist
    using() <| $(var ent : IntersectedEntity#)
      ent.eid = sphere_eid
      ent.t = dist
      ent.collNodeId = -1
      ent.pos = from + dir * dist
      ent.norm = normalize(ent.pos - sphere_pos)
      ent.depth = 0
      intersections |> push_clone(ent)


def trace_traceable_spheres_in_grid(from : float3;
                                    dir : float3;
                                    var t : float&;
                                    var intersections : IntersectedEntities | #)
  for_each_entity_in_grid(ecs_hash("traceable_spheres"), from, dir, t, /*radius*/ 10.0, GridEntCheck.BOUNDING) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE=traceable_sphere)] (transform : float3x4;
                                                    sphere_zone__radius : float)
      trace_traceable_sphere(from, dir, eid, transform[3], sphere_zone__radius, t, intersections)


def trace_traceable_spheres_by_query(from : float3;
                                     dir : float3;
                                     var t : float&;
                                     var intersections : IntersectedEntities | #)
  query() <| $ [es(REQUIRE=traceable_sphere)] (eid : EntityId;
                                               transform : float3x4;
                                               sphere_zone__radius : float)
    trace_traceable_sphere(from, dir, eid, transform[3], sphere_zone__radius, t, intersections)


def traceray_normalized_exclude_ri(skip_riex_handle : uint64;
                                   pos : float3;
                                   dir : float3;
                                   var t : float&;
                                   var out_pmid : int&;
                                   var out_norm : float3&;
                                   flags : int;
                                   var out_desc : RendInstDesc;
                                   ray_mat_id : int)
  var res = false
  if (flags & ETF_FRT) != 0
    res ||= traceray_normalized_frt(pos, dir, t, out_pmid, out_norm)
  if (flags & ETF_RI) != 0
    res ||= traceray_normalized_ri(pos, dir, t, out_pmid, out_norm, flags, out_desc, ray_mat_id, skip_riex_handle)
  if (flags & (ETF_LMESH | ETF_HEIGHTMAP)) != 0
    res ||= traceray_normalized_lmesh(pos, dir, t, out_pmid, out_norm)

  return res


def traceray_exclude_non_phys_collidable(trace_from : float3;
                                         trace_dir : float3;
                                         trace_dist : float;
                                         flags : int = ETF_DEFAULT;
                                         ray_mat_id = -1)
  var hitResult = false
  var riDesc = RendInstDesc()
  var norm : float3
  var t = trace_dist
  var matId = PHYSMAT_INVALID
  if traceray_normalized(trace_from, trace_dir, t, matId, norm, flags, riDesc, ray_mat_id)
    hitResult = true
    if riDesc.isValid
      let collres = getRiGenCollisionResource(riDesc)
      if collres != null
        let riTm = getRIGenMatrix(riDesc)
        let behFlag = uint8(BehaviorFlag.PHYS_COLLIDABLE)
        t = trace_dist
        // Check if this RI have no phys collider - if so, we can ignore it
        // (f.e. this can be some curbs where phys colliders removed by purpose)
        *collres |> collres_traceray(riTm, null, trace_from, trace_dir, t, true, behFlag) <| $ [unused_argument(isects)] (is_hit : bool; isects : CollResIntersectionsType#)
          if is_hit
            return

          hitResult = false

          // Extra reverse trace to check for another obstacles
          let traceTo = trace_from + trace_dir * trace_dist
          t = trace_dist
          var riDesc2 = RendInstDesc()
          let reverseTraceDir = -trace_dir
          if traceray_normalized(traceTo, reverseTraceDir, t, matId, norm, flags, riDesc2, ray_mat_id)
            // If another RI is blocked the trace
            if riDesc2.isValid && riDesc.riExtraHandle != riDesc2.riExtraHandle
              hitResult = true

  return hitResult