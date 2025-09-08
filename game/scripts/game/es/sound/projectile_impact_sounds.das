require ecs
require ecs.safe
require sound_utils.modules.sound_physmat_common
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_occlusion_common
require game.events.events_game
require game.events.events_active_matter
require BallisticsProps
require soundEvent
require PhysMat


def is_armored(parts_armor : FloatList const?; node_id : int; sound_tags : Object)
  return parts_armor != null ? (node_id >= 0 && node_id < length(*parts_armor) && (*parts_armor)[node_id] != 0.) : read_sound_tag("armored", sound_tags)


[es(tag=sound)]
def projectile_hit_entity_fx_sound(evt : OnShellHitEntityFx;
                                   eid : EntityId;
                                   @shared_comp projectile_hit_entity_fx_sound__paths : Object;
                                   dm_parts__type : StringList const?;
                                   dm_parts__partsArmor : FloatList const?;
                                   is_watched_sound : bool = false;
                                   sound_tags : Object)
  if eid != evt.victimEid
    return

  var caliber = 0.
  var isShell = false
  query(evt.projectileEid) <| $ [es] (projectile_sound__shellCaliberThreshold : float)
    projectile_get_props(int(evt.shellId)) <| $(props : ProjectileProps)
      caliber = props.caliber
      isShell = props.caliber >= projectile_sound__shellCaliberThreshold

  let stoppedPath = projectile_hit_entity_fx_sound__paths.stopped ?as Object
  let defaultPath = projectile_hit_entity_fx_sound__paths.unstopped ?as Object

  var path = evt.stopped && stoppedPath != null ? stoppedPath : defaultPath
  if path != null
    path = isShell ? ((*path).shell ?as Object) : ((*path).bullet ?as Object)
  else
    path = isShell ? (projectile_hit_entity_fx_sound__paths.shell ?as Object) : (projectile_hit_entity_fx_sound__paths.bullet ?as Object)

  if dm_parts__type != null && uint(evt.nodeCollId) < uint(length(*dm_parts__type))
    let partName = "part_{(*dm_parts__type)[evt.nodeCollId]}"
    let part = get_desc(*path, partName)
    path = part != null ? part : path

  var hitPath = ""
  if path != null && get_option_path(*path, sound_tags, is_watched_sound, hitPath)
    let armored = is_armored(dm_parts__partsArmor, evt.nodeCollId, sound_tags) ? 1 : 0
    let smid = int(get_projectile_sound_material_id(evt.pmid))
    oneshot("[cal={caliber};mat={smid};armored={armored}]{hitPath}", prevent_wall_sound_occlusion(evt.pos, evt.norm))


[es(tag=sound)]
def projectile_impact_sounds_on_hit_scene(evt : EventProjectileHitScene;
                                          projectile_ballistics_props : ProjectileProps;
                                          projectile__exploded : bool;
                                          projectile_sound__shellCaliberThreshold : float;
                                          @shared_comp projectile_sound__paths : Object;
                                          projectile_sound__ricoThreshold : float)
  if !evt.sceneIntersectionsExceeded || (evt.shouldStop && evt.allowDetonation)
    let isShell = projectile_ballistics_props.caliber >= projectile_sound__shellCaliberThreshold

    if abs(evt.ricochetAngle) > projectile_sound__ricoThreshold
      let ricoPath = isShell ? (projectile_sound__paths.ricoShell ?? "") : (projectile_sound__paths.ricoBullet ?? "")
      if !empty(ricoPath)
        let smid = int(get_projectile_sound_material_id(evt.matId))
        oneshot("[cal={projectile_ballistics_props.caliber};mat={smid}]{ricoPath}", prevent_wall_sound_occlusion(evt.pos, evt.norm))
        if !evt.shouldStop
          return

    let path = projectile_sound__paths[isShell ? (projectile__exploded ? "explodeShell" : "hitShell") : (projectile__exploded ? "explodeBullet" : "hitBullet")] ?? ""
    if !empty(path)
      let smid = int(get_projectile_sound_material_id(evt.matId))
      oneshot("[cal={projectile_ballistics_props.caliber};mat={smid}]{path}", prevent_wall_sound_occlusion(evt.pos, evt.norm))


[es(tag=sound, on_event=CmdShellExplosionFx)]
def projectile_impact_sounds_on_shell_explosion(evt : Event;
                                                scene_hit_place__matId : int;
                                                scene_hit_place__pos : float3;
                                                scene_hit_place__norm : float3;
                                                projectile_sound__shellCaliberThreshold : float;
                                                projectile_ballistics_props : ProjectileProps;
                                                @shared_comp projectile_sound__paths : Object)
  let pathId = projectile_ballistics_props.caliber >= projectile_sound__shellCaliberThreshold ? "explodeShell" : "explodeBullet"
  let path = projectile_sound__paths[pathId] ?? ""
  if !empty(path)
    let smid = int(get_projectile_sound_material_id(scene_hit_place__matId))
    oneshot("[cal={projectile_ballistics_props.caliber};mat={smid}]{path}", prevent_wall_sound_occlusion(scene_hit_place__pos, scene_hit_place__norm))
