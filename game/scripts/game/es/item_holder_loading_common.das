module item_holder_loading_common shared
require ecs
require ecs.safe
require math.random
require net
require game.es.ecs_common
require game.events.events
require game.events.events_game
require DagorSystem
require DagorConsole
require game.utils.net_utils
require game.events.inventory_events
require game.events.events_active_matter
require game.es.boxed_item_common
require game.es.inventory_checks_common


def item_holder_start_loading(human_eid : EntityId;
                              target_item_eid : EntityId;
                              container_eid : EntityId;
                              load_item_count : int;
                              starting_item_count : int;
                              load : bool;
                              search_other_containers : bool;
                              loading_process_template : string)
  createEntity(loading_process_template) <| $(init)
    init |> set("item_loading__holderEid", target_item_eid)
    init |> set("item_loading__itemHumanOwner", human_eid)
    init |> set("item_loading__startingItemCount", starting_item_count)
    init |> set("item_loading__totalItemCountToLoad", load_item_count)
    init |> set("item_loading__wishToLoad", load)
    init |> set("item_loading__targetContainer", container_eid)
    init |> set("item_loading__searchOtherContainers", search_other_containers)
