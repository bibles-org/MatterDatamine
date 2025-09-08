require ecs
require DagorMath
require DagorShaders
require AnimV20
require DagorMaterials


[es(tag=render, on_appear)]
def animchar_with_dynamic_emission_appear(evt : Event;
                                          var animchar_render : AnimcharRendComponent;
                                          var animchar_with_dynamic_emission__color : E3DCOLOR&)
  let emissive_color_var = get_shader_variable_id("emissive_color", false)
  let parameters_channel_var = get_shader_variable_id("parameters_channel", false)


  var emissive_color = Color4(float4(0.0))
  recreate_material(animchar_render) <| $(mat)
    mat |> set_int_param(parameters_channel_var, 0)
  *animchar_render.sceneInstance.lodsResource |> scene_lods_gather_mats(0) <| $(used_mat : array<ShaderMaterial?>#)
    for mat in used_mat
      if getColor4Variable(*mat, emissive_color_var, emissive_color)
        break

  if uint(animchar_with_dynamic_emission__color) == 0u
    animchar_with_dynamic_emission__color = E3DCOLOR(emissive_color)


[es(tag=render, on_appear, track=(animchar_with_dynamic_emission__brightness, animchar_with_dynamic_emission__color),
  after=animchar_with_dynamic_emission_appear)]
def animchar_with_dynamic_emission_track_brightness(evt : Event;
                                                    animchar_with_dynamic_emission__color : E3DCOLOR;
                                                    animchar_with_dynamic_emission__brightness : float;
                                                    var dynamic_material_channels_arr : Array)
  var matParams = getRW_ecs_object(dynamic_material_channels_arr[0])
  if matParams != null
    var color = float4(Color4(animchar_with_dynamic_emission__color))
    color.w *= animchar_with_dynamic_emission__brightness
    set(*matParams, "dynmat_param__emissive_color", color)
