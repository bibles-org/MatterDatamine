options no_aot
require ecs
require ecs.safe
require ecs.ecs_template
require math.base
require strings
require dm
require RendInst
require DagorConsole
require DagorDebug3D
require DagorSystem
require DngDm


def get_hp_color(hp : float;
                 max_hp : float)
  if max_hp <= 0.0
    return E3DCOLOR(0xFFFFFFFF)
  let hpProgress = hp / max_hp
  if hpProgress >= 0.66
    return E3DCOLOR(0xFF00FF00)
  elif hpProgress >= 0.33
    return E3DCOLOR(0xFFFBFF00)
  else
    return E3DCOLOR(0xFFFD0000)


[ecs_template]
struct dm_debug_draw
  dm__debugDrawDist : float = 0.0
  dm__debugDrawDistSq : float = 0.0


[console_cmd(name="dm.debug_hp")]
def dm_debug_draw_cmd(dist = 50.0)
  let tmpl = "dm_debug_draw"
  let distSq = square(dist)

  let exists = find_query() <| $ [es] (eid : EntityId;
                                       var dm__debugDrawDist : float&;
                                       var dm__debugDrawDistSq : float&)
    if dm__debugDrawDist == dist
      destroyEntity(eid)
    else
      dm__debugDrawDist = dist
      dm__debugDrawDistSq = distSq
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("dm__debugDrawDist", dist)
      init |> set("dm__debugDrawDistSq", distSq)


[es(tag=(render, dev), no_order)]
def debug_draw_dm_hp_es(evt : UpdateStageInfoRenderDebug;
                        dm__debugDrawDistSq : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false
    query() <| $ [es] (transform aka dm_transform : float3x4;
                       damage_model : DamageModel)
      let distSq = distance_sq(camera_transform[3], dm_transform[3])
      if distSq > dm__debugDrawDistSq
        return

      for i in range(get_damage_part_props_count(damage_model.dmData))
        let markPos = dm_transform[3]
        let name = get_part_name(damage_model.dmData, i)
        let hp = get_part_hp(damage_model.dmData, PartId(uint(i)))
        let maxHp = get_max_hp(damage_model.dmData, i)
        add_debug_text_mark(markPos, "{name} {fmt(":.2f", hp)}/{fmt(":.2f", maxHp)}", -1, float(i), get_hp_color(hp, maxHp))

    return true

