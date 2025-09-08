require ecs
require DagorRandom
require DagorMath
require AnimV20
require DagorMaterials

[es(tag=render, on_appear, REQUIRE=am_crystal_random_noise_offset)]
def set_noise_offset_on_create(evt : Event; var animchar_render : AnimcharRendComponent)
  let offset = float4(rnd_float(-2.0f, 2.0f), rnd_float(-2.0f, 2.0f), rnd_float(-2.0f, 2.0f), 0.0f)
  recreate_material(animchar_render) <| $(mat)
    mat |> set_color4_param(get_shader_variable_id("crystal_noise_offset", true), Color4(offset))
