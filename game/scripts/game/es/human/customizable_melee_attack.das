require ecs
require ecs.safe
require AnimV20
require DagorRandom
require game.events.events_game


[es(tag=gameClient, on_appear)]
def customizable_melee_attack_init(evt : Event;
                                   animchar : AnimcharBaseComponent;
                                   var customizable_melee_attack__attackTypeAnimVarId : int&)
  assume animGraph = animchar.animGraph
  let paramId = *animGraph |> anim_graph_getParamId("attack_type", int(PT_ScalarParam))
  if paramId >= 0
    customizable_melee_attack__attackTypeAnimVarId = paramId


[es(tag=gameClient, REQUIRE=actions)]
def customizable_melee_attack_apply(evt : RunActionCmd;
                                    customizable_melee_attack__attackTypeAnimVarId : int;
                                    actions__actions : Array;
                                    customizable_melee_attack__description : Object;
                                    var animchar : AnimcharBaseComponent;
                                    var customizable_melee_attack__isPowerfullAttack : bool&;
                                    var customizable_melee_attack__attackDirection : float2&)
  let actionName = (actions__actions[evt.id] as Object)?.name ?? ""
  let meleeAttackDescs = customizable_melee_attack__description[actionName] ?as Array
  if meleeAttackDescs != null && length(*meleeAttackDescs) > 0
    let meleeAttackDesc = (*meleeAttackDescs)[grnd() % length(*meleeAttackDescs)] as Object
    let attackTypeIdx = meleeAttackDesc?.attackType ?? -1
    if attackTypeIdx >= 0
      customizable_melee_attack__isPowerfullAttack = meleeAttackDesc?.isPowerfull ?? false
      customizable_melee_attack__attackDirection = meleeAttackDesc?.direction ?? float2(0.0)
      if customizable_melee_attack__attackTypeAnimVarId >= 0
        assume animState = animchar.animState
        *animState |> anim_state_holder_setParam(customizable_melee_attack__attackTypeAnimVarId, float(attackTypeIdx))
