require ecs
require DngDm
require math.base
require DagorMath
require game.events.events_game

[es(tag=server, REQUIRE=(phys_vars))]
def spawn_attract_point_on_grenade(evt : EventShellExplodedServer; shell__owner : EntityId; transform : float3x4;
                                   shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id : int;
                                   grenades_attract_point__templateName : string; grenades_attract_point__ttl, grenades_attract_point__referenceRadius : float;
                                   grenades_attract_point__radius : float)
  if !shell__owner
    return
  let radius = (grenades_attract_point__radius > 0f ? grenades_attract_point__radius :
    get_shell_max_radius(shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id))
  if radius <= 0f
    return
  let pointMagnitude = safediv(radius, grenades_attract_point__referenceRadius)
  if pointMagnitude > 0f
    createEntity(grenades_attract_point__templateName) <| $(ini)
      var tm = IDENT_TM
      tm[3] = transform[3]
      ini |> set("transform", tm)
      ini |> set("attract_point__magnitude", pointMagnitude)
      ini |> set("game_effect__timeToDestroy", grenades_attract_point__ttl)
      ini |> set("attract_point__ownerEid", shell__owner)
