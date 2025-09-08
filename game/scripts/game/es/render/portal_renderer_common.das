module portal_renderer_common shared
require ecs
require math.base
require DagorMath
require PortalRenderer

def make_portal_params(portal_range : float; use_dense_fog : bool; fog_start_dist : float) : PortalParams
  return <- PortalParams(portalRange = portal_range, useDenseFog = use_dense_fog, fogStartDist = fog_start_dist)

def create_portal_at_tm(source_tm : float3x4; target_tm : float3x4;
                        portal_range : float = 200.0; use_dense_fog : bool = false; fog_start_dist : float = 10.0)
  let sourcePos = source_tm[3]
  let targetPos = target_tm[3]

  var sourceTm = IDENT_TM
  sourceTm[3] = sourcePos
  var targetTm = IDENT_TM
  targetTm[3] = targetPos

  createEntity("dynamic_portal") <| $(init)
    set(init, "transform", sourceTm)
    set(init, "target_transform", targetTm)
    set(init, "portal_range", portal_range)
    set(init, "use_dense_fog", use_dense_fog)
    set(init, "fog_start_dist", fog_start_dist)
