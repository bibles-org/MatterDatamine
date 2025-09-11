require ecs
require danetlibs.damage_decals.damage_decals_events
require DngDm
require Ballistics
require BallisticsProps
require DamageDecals
require BulletHoles
require DngWeapon
require DagorSystem

// The following table was used for claculating formula
// based on 5 different weapons (all values are represented in SI - meters, Jouls, etc):
// Energy |	Caliber	| Decal radius
// --------------------------------
// 62.26    0.00111   0.0054
// 285      0.009     0.0108
// 2847     0.00762   0.0171
// 521      0.0114    0.0126
// 17457    0.0127    0.0294

[es(tag=render, REQUIRE_NOT=disableRIBulletHole)]
def projectile_bullet_hole_on_ri_es(evt : CmdRendinstBulletHole;
                                    projectile_ballistics_props : ProjectileProps;
                                    projectile_ballistics : ProjectileBallistics;
                                    dm_projectile_state : ProjectileState;
                                    bullet_holes__shellCaliberThreshold : float = 0.02;
                                    bullet_holes__bulletCaliberMult : float = 8.2858e-03;
                                    bullet_holes__energyExponent : float = 0.1859;
                                    bullet_holes__caliberExponent : float = 0.1645;
                                    bullet_holes__bulletCaliberMin : float = 0.00648;
                                    bullet_holes__bulletCaliberMax : float = 0.03;
                                    bullet_holes__shellCaliberMult : float = 1.25)
  let decal = get_bullet_decal(uint16(dm_projectile_state.projectileTypePropsId))
  let damageType = decal != null ? string(decal.stop) : ""
  let caliber = projectile_ballistics_props.caliber
  var decalSize = caliber
  if (caliber < bullet_holes__shellCaliberThreshold)
    let speedSq = length_sq(projectile_ballistics.state.vel)
    let energy = projectile_ballistics_props.mass * speedSq * 0.5 // kinetic energy formula
    decalSize = bullet_holes__bulletCaliberMult * pow(energy, bullet_holes__energyExponent) * pow(caliber, bullet_holes__caliberExponent)
    // here clamp to avoid extra small and extra big bullet holes
    // min value is 60% of avg 9mm result size
    // max value just a little bit bigger then shellTreshold
    decalSize = clamp(decalSize, bullet_holes__bulletCaliberMin, bullet_holes__bulletCaliberMax)
  else
    decalSize *= bullet_holes__shellCaliberMult // for tank shell we just increse caliber by  quarter, for consistent looking
  let decalId = create_ri_projective_damage_decal(evt.pos, evt.dir, evt.norm, evt.riHandle, decalSize, evt.pmid, damageType)
  let created = decalId >= 0
  if created && damageType == "bomb_hit"
    createEntity("rendinst_bomb_hit_decal") <| $(init)
      set(init, "ri_bomb_hit_decal__id", decalId)
      set(init, "ri_bomb_hit_decal__pos", evt.pos)
  if !created
    //billboard decal
    add_projectile_bullet_hole(evt.riHandle, evt.pos, evt.norm, evt.pmid, decalSize)
