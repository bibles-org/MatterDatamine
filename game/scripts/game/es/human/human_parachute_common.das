module human_parachute_common shared
require ecs
require Dacoll


enum ParachuteState
  NONE = -1
  OPENING
  OPENED
  CLOSING
  CLOSED


def get_parachute_altitude(pos, gravDir : float3; max_trace_dist : float)
  var altitude = max_trace_dist
  var norm : float3
  var pmat : int
  var riDesc = RendInstDesc()
  traceray_normalized(pos, gravDir, altitude, pmat, norm, ETF_DEFAULT, riDesc, -1)

  var waterHeight = 0.0
  if traceht_water(pos, waterHeight)
    let waterAltitude = pos.y - waterHeight
    altitude = min(altitude, waterAltitude)

  return altitude
