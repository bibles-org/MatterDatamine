require ecs
require math
require DngDm
require AnimV20
require HumanPhys
require DngHuman
require Dacoll
require GeomNodeTree
require game.events.events_active_matter

[es(tag=server, REQUIRE_NOT=(disableUpdate, deadEntity), no_order)]
def human_breath_is_under_water_es(info : ParallelUpdateFrameDelayed;
                                   animchar : AnimcharBaseComponent;
                                   human_net_phys : HumanActor;
                                   isInVehicle : bool = false;
                                   breath_node__nodeId : int;
                                   var human_breath__isUnderWater : bool&)
  if (breath_node__nodeId < 0)
    return

  if human_phys_state_get_is_underwater(human_net_phys.phys.currentState) && !isInVehicle
    human_breath__isUnderWater = true
  else
    let pos = geomtree_getNodeWpos(*animchar.nodeTree, breath_node__nodeId)
    if !is_valid_water_height(traceht_water_at_time(pos, 5.f, info.curTime, human_breath__isUnderWater))
      human_breath__isUnderWater = false


[es(REQUIRE_NOT=(disableUpdate, deadEntity), after=human_breath_is_under_water_es)]
def human_breath_timer_es(act : ParallelUpdateFrameDelayed;
                          eid : EntityId;
                          var human_breath__timer : float&;
                          var human_breath__asphyxiationTimer : float&;
                          human_breath__maxHoldBreathTime : float;
                          transform : float3x4;
                          human_breath__recoverBreathMult : float = 2.0;
                          human_breath__damagePerTick : float = 4.0;
                          human_breath__damageTick : float = 1.0;
                          human_breath__isUnderWater : bool;
                          human_breath__staleBreath = false)
  let canBreath = !human_breath__isUnderWater && !human_breath__staleBreath
  if canBreath
    human_breath__timer = max(human_breath__timer - act.dt * human_breath__recoverBreathMult, 0.0)
  else
    human_breath__timer = min(human_breath__timer + act.dt, human_breath__maxHoldBreathTime)
  if human_breath__timer >= human_breath__maxHoldBreathTime
    human_breath__asphyxiationTimer = human_breath__asphyxiationTimer + act.dt
    if human_breath__asphyxiationTimer > human_breath__damageTick
      human_breath__asphyxiationTimer = human_breath__asphyxiationTimer - human_breath__damageTick
      let damageType = !human_breath__staleBreath ? DamageType.DM_HOLD_BREATH : DamageType.DM_ZONE
      let dd = DamageDesc(damageType, human_breath__damagePerTick, transform[3], float3(0.0, -1.0, 0.0))
      damage_entity(eid, eid, dd)
