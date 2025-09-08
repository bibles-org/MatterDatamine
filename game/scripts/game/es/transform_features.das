require ecs
require math.base
require DagorMath
require DagorRandom
require Dacoll
require PhysMat
require math.random
require level
require game.es.grav_zones_common


[es(on_appear, REQUIRE=transform__axisAligned)]
def axis_aligned_transform_appear(evt : Event; var transform : float3x4)
  let scaleX = length(transform[0])
  let scaleY = length(transform[1])
  let scaleZ = length(transform[2])
  transform[0] = float3(scaleX, 0., 0.)
  transform[1] = float3(0., scaleY, 0.)
  transform[2] = float3(0., 0., scaleZ)


[es(on_appear, REQUIRE=transform__scaleToMaxAxis)]
def scaled_to_max_axis_transform_appear(evt : Event; var transform : float3x4)
  let len0 = length(transform[0])
  let len1 = length(transform[1])
  let len2 = length(transform[2])
  let targetSize = max(len0, len1) |> max(len2)
  transform[0] *= safediv(targetSize, length(transform[0]))
  transform[1] *= safediv(targetSize, length(transform[1]))
  transform[2] *= safediv(targetSize, length(transform[2]))


[es(on_appear, REQUIRE=transform__scaleToMinAxis)]
def scaled_to_min_axis_transform_appear(evt : Event; var transform : float3x4)
  let len0 = length(transform[0])
  let len1 = length(transform[1])
  let len2 = length(transform[2])
  let targetSize = min(len0, len1) |> min(len2)
  transform[0] *= safediv(targetSize, length(transform[0]))
  transform[1] *= safediv(targetSize, length(transform[1]))
  transform[2] *= safediv(targetSize, length(transform[2]))


[es(on_appear, tag=server)]
def random_scale_transform_appear(evt : Event; eid : EntityId; transform__randomInitialScale : float2; var transform : float3x4)
  var seed = int(uint(eid))
  let targetScale = lerp(transform__randomInitialScale.x, transform__randomInitialScale.y, _frnd(seed))
  transform[0] *= targetScale
  transform[1] *= targetScale
  transform[2] *= targetScale
  var q : quat
  euler_to_quat(RAD_TO_DEG * 2.0 * PI * _frnd(seed), 0.0, 0.0, q)
  var rotateTm = IDENT_TM
  make_tm(q, rotateTm)
  transform = transform * rotateTm


[es(on_appear, REQUIRE=transform__NBSSphereRadius)]
def transform_nbs_sphere_radius_appear(evt : Event;
                                       transform : float3x4;
                                       transform__inflateNBSSphereRadius = 0.;
                                       var nbs_sphere__radius : float&)
  let len0 = length(transform[0])
  let len1 = length(transform[1])
  let len2 = length(transform[2])
  nbs_sphere__radius = transform__inflateNBSSphereRadius + 0.5 * max(max(len0, len1), len2)


[es(on_appear, REQUIRE=transform__groundAlign)]
def transform_ground_align_appear(evt : Event; transform__groundAlignHeight = 5.; var transform : float3x4)
  let pos = transform[3] + float3(0, 1, 0) * transform__groundAlignHeight
  var t = transform__groundAlignHeight * 2.
  var norm : float3
  if tracedown_normalized(pos, t, norm, ETF_LMESH | ETF_HEIGHTMAP)
    transform[1] = normalize(norm)
    transform[0] = cross(transform[1], transform[2])
    transform[2] = cross(transform[0], transform[1])


[es(on_appear, on_event=EventRetriggerEntity, REQUIRE=transform__dropOnGroundOnAppear)]
def transform_drop_on_ground(evt : Event; eid : EntityId; var transform : float3x4; transform__dropOnGroundMaxHeight = 5.; transform__dropOnGroundOffset = 0.)
  if wake_me_up_when_gravzones_are_loaded(eid)
    return
  var height = transform__dropOnGroundMaxHeight
  let pointPos = transform[3]
  let down = get_grav_dir(pointPos)
  var pmid = PHYSMAT_INVALID
  var norm : float3
  var riDesc = RendInstDesc()
  if traceray_normalized(pointPos, down, height, pmid, norm, ETF_DEFAULT, riDesc, -1)
    let hitPos = pointPos + down * height
    transform[3] = hitPos - down * transform__dropOnGroundOffset


[es(on_appear)]
def transform_local_tm(evt : Event; transform__localTm : float3x4; var transform : float3x4)
  transform = transform * transform__localTm
