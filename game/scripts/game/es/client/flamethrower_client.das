require ecs
require game.es.swarm_common
require AnimV20
require GeomNodeTree


[es(tag=gameClient, after=human_weap_update_es)]
def flamethrower_damage_client(act : UpdateStageInfoAct;
                               flamethrower__flameCurrentLength : float;
                               flamethrower__flameCloudRadius : float;
                               flamethrower__cloudStartOffset : float;
                               flamethrower__active : bool;
                               animchar : AnimcharBaseComponent;
                               flamethrower__streamEffectNodeIdx : int;
                               slot_attach__attachedTo : EntityId;
                               flamethrower__flameCloudRadiusSwarmMult : float = 2.0)
  if flamethrower__active && flamethrower__flameCurrentLength > flamethrower__cloudStartOffset
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, flamethrower__streamEffectNodeIdx, tm)
    let gunPos = tm[3]
    let gunDir = tm[1]
    assume cloudRadius = flamethrower__flameCloudRadius
    let fireLen = max(0.0, flamethrower__flameCurrentLength - cloudRadius)
    let fireCloudStart = gunPos + gunDir * flamethrower__cloudStartOffset
    // Swarms work on client side, so we will also burn them on client side
    apply_swarm_fire_cloud_damage(slot_attach__attachedTo,
                                  fireCloudStart, gunDir, fireLen,
                                  cloudRadius * flamethrower__flameCloudRadiusSwarmMult)