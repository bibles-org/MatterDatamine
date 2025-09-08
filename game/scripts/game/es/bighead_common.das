module bighead_common shared

require ecs.enum_macro
require ecs
require math.random
require math.base
require DagorMath
require game.es.grav_zones_common


[export_enum]
enum BigheadAttackState
  NONE
  PREPARE
  ATTACK
  DONE


def create_floating_object(ri_name_list : StringList;
                           var seed : int;
                           owner_transform : float3x4;
                           owner_eid : EntityId;
                           min_max_ellipse_height : float2;
                           ellipse_width_height_ratio : float;
                           min_max_orbit_angles_deg : float2;
                           min_max_speed : float2;
                           min_max_oscillation_amplitude : float2;
                           min_max_oscillation_frequency : float2;
                           object_template : string;
                           init_callback : block<(var i : ecs::ComponentsInitializer) : void>) : EntityId
  assume riName = ri_name_list[rnd_int(0, length(ri_name_list) - 1)]
  let ellipseHeight = _rnd_float(seed, min_max_ellipse_height)
  let ellipseWidth = ellipseHeight * ellipse_width_height_ratio
  let initialEllipseParam = _rnd_float(seed, float2(0.0, 2.0 * PI))
  let minOrbitAngle = deg_to_rad(min_max_orbit_angles_deg.x)
  let maxOrbitAngle = deg_to_rad(min_max_orbit_angles_deg.y)
  let orbitAngle = _rnd_float(seed, float2(minOrbitAngle, maxOrbitAngle))
  let initialSpeed = _rnd_float(seed, float2(min_max_speed.x, min_max_speed.y))
  let oscillationFrequency = _rnd_float(seed, min_max_oscillation_frequency.x, min_max_oscillation_frequency.y)
  let oscillationAmplitude = _rnd_float(seed, min_max_oscillation_amplitude.x, min_max_oscillation_amplitude.y)
  let rnd = float2(-0.5, 0.5)
  let oscillationOrigin = float3(_rnd_float(seed, rnd), _rnd_float(seed, rnd), _rnd_float(seed, rnd))
  return createEntity(object_template) <| $(i)
    var tm = IDENT_TM
    tm[3] = calc_floating_object_ellipse_position(ellipseHeight,
                                                  ellipseWidth,
                                                  initialEllipseParam,
                                                  orbitAngle,
                                                  owner_transform[3])
    set(i, "transform", tm)
    set(i, "ri_extra__name", riName)
    set(i, "floating_object__owner", owner_eid)
    set(i, "floating_object__ellipseHeight", ellipseHeight)
    set(i, "floating_object__ellipseWidth", ellipseWidth)
    set(i, "floating_object__currentEllipseParam", initialEllipseParam)
    set(i, "floating_object__orbitAngle", orbitAngle)
    set(i, "floating_object__speed", initialSpeed)
    set(i, "euler_sinusoidal_oscillation__amplitude", float3(oscillationAmplitude))
    set(i, "euler_sinusoidal_oscillation__frequency", float3(oscillationFrequency))
    set(i, "euler_sinusoidal_oscillation__origin", oscillationOrigin)
    init_callback |> invoke(i)


def calc_floating_object_ellipse_position(ellipse_height : float;
                                          ellipse_width : float;
                                          ellipse_param : float;
                                          orbit_angle : float;
                                          center_position : float3)
  let up = -get_grav_dir(center_position, true)
  let right = float3(0.0, 0.0, 1.0)
  var rotTm : float3x4
  make_tm(right, orbit_angle, rotTm)
  let orbitNormal = rotTm * up
  var sinParam, cosParam : float
  sincos(ellipse_param, sinParam, cosParam)
  let x = ellipse_height * cosParam
  let y = ellipse_width * sinParam
  return center_position + x * right + y * cross(right, orbitNormal)
