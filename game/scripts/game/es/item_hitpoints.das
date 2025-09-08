require ecs
require ecs.safe
require ecs.common
require math.random
require net
require DagorMath
require game.events.events_active_matter


[es(tag=server)]
def on_damage_item_event(evt : CmdDamageItem;
                         eid aka item_eid : EntityId;
                         item__minDamageGap : float = 0.0;
                         item__maxDamageGap : float = VERY_BIG_NUMBER;
                         var item__hp : float&)
  if item__hp < 0.0
    return

  let damage = min(max(item__minDamageGap, evt.damage), item__maxDamageGap)

  item__hp -= damage
  if item__hp <= 0.0
    item__hp = min(-1e-6, item__hp) // prevent zero hp value
    send_net_event(item_eid, CmdItemDestroyed(damageType = evt.damageType))
    destroyEntity(item_eid)


[es(tag=server, on_appear)]
def item_initial_damage(evt : Event;
                        item__initDamageKoefs : float2;
                        item__maxHp : float;
                        var item__hp : float&)
  item__hp = rnd_float(item__initDamageKoefs) * item__maxHp