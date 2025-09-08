module visual_attraction_common shared
require math

def logistic(x : float; k = 1.; max = 1.)
  return max / (1. + exp(-k * x))


def calc_traceable_ratio(cur_time : float; last_trace_time : float; dist, max_dist : float; radius : float) : float
  let timeMult = min(5f, cur_time - last_trace_time)
  return logistic(dist - max_dist, -0.5, 1f) * timeMult * radius