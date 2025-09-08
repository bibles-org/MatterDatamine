require ecs
require math.base


[es(on_appear)]
def create_bot_look_pos(evt : Event;
                        eid : EntityId;
                        transform : float3x4;
                        create_bot_look_pos__offsetComponent : string;
                        var create_bot_look_pos__eidBb : int&;
                        var create_bot_look_pos__eid : EntityId&)
  let offset = get_Point3(eid, create_bot_look_pos__offsetComponent, ecs_hash(create_bot_look_pos__offsetComponent)) ?? float3(0.0)
  create_bot_look_pos__eid = createEntity("bot_look_pos") <| $(init)
    var tm = IDENT_TM
    tm[3] = transform * offset
    set(init, "transform", tm)
  create_bot_look_pos__eidBb = int(uint(create_bot_look_pos__eid))


[es(on_appear, track=transform)]
def move_bot_look_pos(evt : Event;
                      eid : EntityId;
                      transform aka owner_transform : float3x4;
                      create_bot_look_pos__offsetComponent : string;
                      create_bot_look_pos__eid : EntityId)
  query(create_bot_look_pos__eid) <| $ [es] (var transform aka look_pos_transform : float3x4&)
    let offset = get_Point3(eid, create_bot_look_pos__offsetComponent, ecs_hash(create_bot_look_pos__offsetComponent)) ?? float3(0.0)
    look_pos_transform[3] = owner_transform * offset


[es(on_disappear)]
def cleanup_bot_look_pos(evt : Event; create_bot_look_pos__eid : EntityId)
  destroyEntity(create_bot_look_pos__eid)
