require ecs
require DagorShaders


let
  night_light_mult_var_id = get_shader_variable_id("night_light_mult", true)
  night_light_dist_mult_var_id = get_shader_variable_id("night_light_dist_mult", true)


[es(tag=render, on_appear, REQUIRE=watchedByPlr)]
def night_light_params_set(evt : Event;
                           night_light__lightMult = 0.0;
                           night_light__lightDistanceMult = 0.0)
  DagorShaders::set_real(night_light_mult_var_id, night_light__lightMult)
  DagorShaders::set_real(night_light_dist_mult_var_id, night_light__lightDistanceMult)
