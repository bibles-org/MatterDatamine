module soldier_inventory_events shared
require ecs

[cpp_event(unicast, with_scheme)]
struct EventUseItem
  item : EntityId
  target : EntityId
