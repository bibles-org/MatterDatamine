require ecs
require DngDm
require DagorRandom
require math.base
require game.events.events_active_matter
require game.es.riextra_damage_common
require app
require RendInst


def get_damage_pos(transform : float3x4 const?; game_effect__ownerEid : EntityId)
  if transform != null
    return (*transform)[3]
  return (get_TMatrix(game_effect__ownerEid, "transform") ?? IDENT_TM)[3]


[es(tag=server)]
def do_damage_target_affect(evt : ApplyGameAffect; transform : float3x4 const?;
                            game_effect__ownerEid : EntityId;
                            game_effect__damageTargetDeltaHp : float;
                            game_effect__damageTargetDeltaHpRandom : float = 0.0;
                            game_effect__damageType : int = -1)

  let damageRandomPart = game_effect__damageTargetDeltaHpRandom > 0.0 ? game_effect__damageTargetDeltaHpRandom * gfrnd() : 0.0
  let damage = game_effect__damageTargetDeltaHp + damageRandomPart
  let pos = get_damage_pos(transform, game_effect__ownerEid)

  if has(evt.targetEid, "ri_extra")
    query(evt.targetEid) <| $ [es] (ri_extra : RiExtraComponent)
      damage_ri_on_server(ri_extra.handle, damage, pos, float3(), get_sync_time(), evt.targetEid)
    return

  let damageType = game_effect__damageType == -1 ? DamageType.DM_MELEE : DamageType(game_effect__damageType)
  let damageDesc = DamageDesc(damageType, damage, pos)
  damage_entity(evt.targetEid, game_effect__ownerEid, damageDesc)
