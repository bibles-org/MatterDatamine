require ecs
require Dacoll
require DamageDecals
require DngDm
require danetlibs.weapons.shell_events

def trace_and_spawn_grenade_explosion_decal(pos : float3; rad : float)
  var height = 0.3
  var norm : float3
  var pmid : int
  if tracedown_normalized(pos, height, pmid, norm, ETF_DEFAULT)
    let dir = -norm
    create_ri_projective_damage_decal(pos, dir, norm, RIEX_HANDLE_NULL, rad, pmid, "grenade_explosion")

[es(tag=render, REQUIRE=msg_sink)]
def grenade_explosion_decal(evt : CmdShellExplodeClient)
  // We use `fxInfoEid` only for non projectile explosive shells, like grenades, explosiove packs or mines
  if evt.fxInfoEid == INVALID_ENTITY_ID
    return
  splash_params_get_props(int(evt.shellId.damageId)) <| $(props : SplashParamsProps)
    trace_and_spawn_grenade_explosion_decal(evt.pos, props.radius.x)