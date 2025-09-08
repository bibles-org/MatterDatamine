module anim_common shared
require ecs


def add_irq_event_name(var anim_irq__eventNames : Object;
                       irq_name : string)
  using <| $(var irq : Object)
    irq |> set("irqName", irq_name)
    irq |> set("irqId", -1)
    anim_irq__eventNames |> set(irq_name, irq)
