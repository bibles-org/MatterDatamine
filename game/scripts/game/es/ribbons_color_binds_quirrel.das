require ecs
require ecs.ecs_quirrel
require DagorSystem


def get_color(shader_color__colors : Point4List;
              color_idx : int)
  var color : array<float>
  color |> push(shader_color__colors[color_idx].x)
  color |> push(shader_color__colors[color_idx].y)
  color |> push(shader_color__colors[color_idx].z)
  color |> push(shader_color__colors[color_idx].w)
  return <- color


[quirrel_bind(module_name="das.ribbons_color")]
def get_primary_color_of_hero(hero_eid : EntityId)
  var color : array<float>

  query(hero_eid) <| $ [es] (shader_color__colors aka hero_shader_color__colors : Point4List const?;
                             attachable_suit_controller__attachedAnimcharEids : Object const?)
    let topEid = attachable_suit_controller__attachedAnimcharEids |> get_Eid("top")
    if topEid != null
      query(*topEid) <| $ [es] (shader_color__colors aka suit_shader_color__colors : Point4List)
        color <- get_color(suit_shader_color__colors, 0)
    elif hero_shader_color__colors != null
      color <- get_color(*hero_shader_color__colors, 0)

  return <- color


[quirrel_bind(module_name="das.ribbons_color")]
def get_secondary_color_of_hero(hero_eid : EntityId)
  var color : array<float>

  query(hero_eid) <| $ [es] (shader_color__colors aka hero_shader_color__colors : Point4List const?;
                             attachable_suit_controller__attachedAnimcharEids : Object const?)
    let topEid = attachable_suit_controller__attachedAnimcharEids |> get_Eid("top")
    if topEid != null
      query(*topEid) <| $ [es] (shader_color__colors aka suit_shader_color__colors : Point4List)
        color <- get_color(suit_shader_color__colors, 1)
    elif hero_shader_color__colors != null
      color <- get_color(*hero_shader_color__colors, 1)

  return <- color


[quirrel_bind(module_name="das.ribbons_color")]
def get_color_idx_of_hero(hero_eid : EntityId)
  var colorIdx : int2
  query(hero_eid) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es] (player_ribbons__curColors : int2)
      colorIdx = player_ribbons__curColors
  return colorIdx


[quirrel_bind(module_name="das.ribbons_color")]
def get_color_by_index(idx : int)
  var color = float4(0.0)
  find_query() <| $ [es] (ribbonColorsList : Point4List;
                          ribbonInvalidColor : float4)
    if idx < 0 || idx >= length(ribbonColorsList)
      color = ribbonInvalidColor
    else
      color = ribbonColorsList[idx]
    return true
  return color


[quirrel_bind(module_name="das.ribbons_color")]
def get_color_name_by_index(idx : int)
  var name = ""
  find_query() <| $ [es] (ribbonColorsListNames : StringList;
                          ribbonInvalidColorName : string)
    if idx < 0 || idx >= length(ribbonColorsListNames)
      name := ribbonInvalidColorName
    else
      name := ribbonColorsListNames[idx]
    return true
  return name


[quirrel_bind(module_name="das.ribbons_color")]
def get_color_as_array_by_index(idx : int)
  let color = get_color_by_index(idx)
  return <- array<float>(color.x, color.y, color.z, color.w)


[quirrel_bind(module_name="das.ribbons_color")]
def get_available_colors()
  var colors : array<float4>
  find_query() <| $ [es] (ribbonColorsList : Point4List)
    for color in ribbonColorsList
      colors |> push(color)
    return true
  return <- colors
