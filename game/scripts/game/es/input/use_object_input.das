require ecs
require game.es.use_object_common

/*
This is the starting function for interactables. It chooses what the player is going to use
based on what they're looking at.
Similar functions try to choose doors, cars, items on ground, stationary guns, grenade rethrows
*/

[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity,
  after=hero_human_use_door_object_es,
  before=(hero_human_use_inventory_es, hero_human_final_use_object_sync))]
def hero_human_use_object(act : UpdateStageInfoAct;
                          eid : EntityId;
                          var human_use_object__canUseSelected : bool&;
                          var human_use_object__selectedObject : EntityId&;
                          var human_use_object__selectedObjectDot : float&;
                          var human_use_object__lookAtSelected : bool&)
  use_usable_object(human_use_object__selectedObject,
                    human_use_object__selectedObjectDot,
                    human_use_object__lookAtSelected,
                    $(object_eid : EntityId) => hero_human_use_object_strict_check(eid, object_eid))
  human_use_object__canUseSelected = true
  //true by default.
  //Other systems should check their custom conditions after=hero_human_use_object, before=hero_human_final_use_object_sync
