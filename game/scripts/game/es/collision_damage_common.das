module collision_damage_common shared
require ecs

def calc_collision_damage(delta_vel : float;
                          vel_thres : float;
                          vel_mult : float;
                          vel_pow : float) : float
  if delta_vel < vel_thres
    return 0.f
  return pow(delta_vel - vel_thres, vel_pow) * vel_mult