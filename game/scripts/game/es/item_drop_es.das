require ecs
require DagorMath
require DagorRandom
require math.base
require game.es.grav_zones_common


[es(on_event=EventOnItemGenerated, tag=server)]
def drop_item_es(evt : Event; var transform : float3x4; dropTm : float3x4; item__isOnGround : bool; var server_transform : float3x4?)
  if item__isOnGround
    transform = transform * dropTm
    if server_transform != null
      *server_transform := transform


[es(on_appear, tag=server)]
def drop_item_created_es(evt : Event; var transform : float3x4; dropTm : float3x4; item__alreadyLooted : bool; var server_transform : float3x4?)
  if item__alreadyLooted
    transform = transform * dropTm
    if server_transform != null
      *server_transform := transform


def randomize_orient_orientation_common(drop_tms : TMatrixList; var transform : float3x4)
  transform = transform * drop_tms[rnd_int(0, length(drop_tms) - 1)]


[es(on_event=EventOnItemGenerated, tag=server)]
def random_orient_drop_item_es(evt : Event; var transform : float3x4; drop_tms : TMatrixList; item__isOnGround : bool)
  if item__isOnGround
    randomize_orient_orientation_common(drop_tms, transform)


[es(on_appear, tag=server)]
def random_orient_drop_item_created_es(evt : Event; var transform : float3x4; drop_tms : TMatrixList; item__alreadyLooted : bool)
  if item__alreadyLooted && !empty(drop_tms)
    randomize_orient_orientation_common(drop_tms, transform)


def randomize_rotate_orientation_common(horizontal_angle_limits : float2; var transform : float3x4)
  let angle = lerp(horizontal_angle_limits.x, horizontal_angle_limits.y, gfrnd()) * DEG_TO_RAD
  let rotQuat = quat(-get_grav_dir(transform[3], true), angle)
  var tm : float3x4
  make_tm(rotQuat, tm)
  let pos = transform[3]
  transform = tm * transform
  transform[3] = pos


[es(on_event=EventOnItemGenerated, tag=server, after=random_orient_drop_item_es)]
def random_rotate_drop_item_es(evt : Event; var transform : float3x4; drop_item__horizontalAngleLimits : float2; item__isOnGround : bool)
  if item__isOnGround
    randomize_rotate_orientation_common(drop_item__horizontalAngleLimits, transform)


[es(on_appear, tag=server, after=random_orient_drop_item_created_es)]
def random_rotate_drop_item_created_es(evt : Event; var transform : float3x4; drop_item__horizontalAngleLimits : float2; item__alreadyLooted : bool)
  if item__alreadyLooted
    randomize_rotate_orientation_common(drop_item__horizontalAngleLimits, transform)
