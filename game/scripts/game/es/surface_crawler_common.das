module surface_crawler_common shared
require ecs
require app
require Dacoll
require DagorRandom
require DagorMath

def surface_crawler_update(dt : float;
                           surface_crawler__lookAhead : float2;
                           surface_crawler__lookDown : float3;
                           surface_crawler__curvePerSecond;
                           surface_crawler__curvePerSecondRnd;
                           surface_crawler__rndInfluence : float;
                           surface_crawler__speed : float;
                           surface_crawler__maxFrustration : int;
                           var surface_crawler__frustration : int&;
                           var surface_crawler__seed : int&;
                           var surface_crawler__head : float3&;
                           var surface_crawler__dir : float3&;
                           var surface_crawler__norm : float3&;
                           var surface_crawler__matId : int&;
                           var surface_crawler__active : bool&;
                           on_ri_encountered : block<(riDesc : RendInstDesc const)>)
  if surface_crawler__frustration > surface_crawler__maxFrustration
    surface_crawler__active = false
    return false

  let dirNoise = _rnd_float(surface_crawler__seed, -1.0, 1.0) * surface_crawler__rndInfluence
  var q = quat(surface_crawler__norm, dirNoise * dt)
  surface_crawler__dir = q * surface_crawler__dir

  var norm : float3
  var pmid : int
  var riDesc = RendInstDesc()
  var t = surface_crawler__lookAhead.y
  let flags = ETF_LMESH | ETF_HEIGHTMAP | ETF_FRT | ETF_RI | ETF_STRUCTURES
  if traceray_normalized(surface_crawler__head, surface_crawler__dir, t, pmid, norm, flags, riDesc, -1)
    //if there is an obstacle -> start rotating norm towards the norm of the obstacle
    // if the obstacle is too close -> set the norm to the norm of the obstacle
    let rotAxis = cross(surface_crawler__norm, norm)
    let fullAngle = acos(dot(surface_crawler__norm, norm))
    var angle = fullAngle
    if t > surface_crawler__lookAhead.x
      angle = lerp(fullAngle, .0, (t - surface_crawler__lookAhead.x) / (surface_crawler__lookAhead.y - surface_crawler__lookAhead.x))
    q = quat(rotAxis, angle)
    surface_crawler__dir = normalize(q * surface_crawler__dir)
    surface_crawler__norm = normalize(cross(rotAxis, surface_crawler__dir))//to ensure they are orthogonal at all times
    if t < surface_crawler__lookAhead.x
      surface_crawler__frustration++ //we are radically changing direction. If this keeps up we're probably stuck.
      return false
  t = surface_crawler__lookDown.z
  let invNorm = -surface_crawler__norm
  traceray_normalized(surface_crawler__head, invNorm, t, surface_crawler__matId, norm, flags, riDesc, -1)
  //let surface = surface_crawler__head + invNorm * t
  if riDesc.isValid
    invoke(on_ri_encountered, riDesc)
  //too close to the surface (t < x)-> go up
  //too far from the surface (t > y) -> go down
  //there is no surface (t = z) -> go down with random fluctuations
  //not too close, not too far (x < t < y) -> do nothing
  let rotAxis = cross(surface_crawler__norm, surface_crawler__dir)
  let rotFullAmount = surface_crawler__curvePerSecond * dt
  var rotAmount = rotFullAmount
  if t < surface_crawler__lookDown.x || t > surface_crawler__lookDown.y
    //draw_debug_circle_buffered(surface + surface_crawler__norm * surface_crawler__lookDown.x, surface_crawler__norm, 0.03, ACBLUE, 4, 200)
    //draw_debug_circle_buffered(surface + surface_crawler__norm * surface_crawler__lookDown.y, surface_crawler__norm, 0.03, ACINDI, 4, 200)
    //draw_debug_sphere_buffered(surface_crawler__head, 0.5, ACWHITE, 1)
    //draw_debug_arrow_buffered(surface_crawler__head, surface_crawler__head + surface_crawler__norm * 0.2, ACYELLOW, 200)
    //draw_debug_arrow_buffered(surface_crawler__head, surface_crawler__head + surface_crawler__dir * 0.2, ACMAGENTA, 200)
    if t < surface_crawler__lookDown.z
      rotAmount = lerp(rotFullAmount, .0, (surface_crawler__lookDown.z - t) / (surface_crawler__lookDown.z - surface_crawler__lookDown.y))
    else
      rotAmount *= _rnd_float(surface_crawler__seed, 1.0 - surface_crawler__curvePerSecondRnd, 1.0 + surface_crawler__curvePerSecondRnd)
  else
    //draw_debug_sphere_buffered(surface_crawler__head, 0.5, ACGREEN, 1)
    //draw_debug_arrow_buffered(surface_crawler__head, surface_crawler__head + surface_crawler__norm * 0.2, ACYELLOW, 200)
    //draw_debug_arrow_buffered(surface_crawler__head, surface_crawler__head + surface_crawler__dir * 0.2, ACINDI, 200)
    // Hang around teh sweet spot
    let sweetSpot = (surface_crawler__lookDown.x + surface_crawler__lookDown.y) * 0.5
    let optimalZoneWidth = sweetSpot - surface_crawler__lookDown.x
    let deviation = t - sweetSpot
    let speedFactor = deviation / optimalZoneWidth
    rotAmount = (surface_crawler__curvePerSecond * speedFactor) * dt * 0.5

  q = quat(rotAxis, rotAmount)
  surface_crawler__norm = q * surface_crawler__norm
  surface_crawler__dir = normalize(cross(rotAxis, surface_crawler__norm)) //to ensure they are orthogonal at all times
  //draw_debug_arrow_buffered(surface_crawler__head, surface_crawler__head + surface_crawler__dir * 0.2, ACCYAN, 200)

  surface_crawler__head = surface_crawler__head + surface_crawler__dir * surface_crawler__speed * dt
  surface_crawler__frustration = 0
  return true