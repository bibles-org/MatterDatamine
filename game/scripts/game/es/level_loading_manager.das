require ecs
require app
require game.events.events_game
require game.events.events
require game.events.events_active_matter
require DagorSystem

[unused_argument(level__loadingGen), es(track=level__loadingGen)]
def log_level_loading_progress(evt : Event;
                               level__loadingGen : int;
                               level__levelLoaded : bool;
                               level__gameObjectsCreated : bool;
                               level__gameObjectsEntitiesCreated : bool;
                               level__movingZoneAppeared : bool;
                               level__movingZoneInited : bool;
                               level__navmeshIslandsMarkerAppeared : bool;
                               level__navmeshIslandsMarked : bool;
                               level__localSceneEntitiesCreated : bool;
                               var level__allLoadedTime : float&;
                               var level__retriggerEids : EidList)
  if (level__levelLoaded &&
      level__gameObjectsCreated &&
      level__gameObjectsEntitiesCreated &&
      level__localSceneEntitiesCreated &&
      (!level__movingZoneAppeared || level__movingZoneInited) &&
      (!level__navmeshIslandsMarkerAppeared || level__navmeshIslandsMarked) &&
      level__allLoadedTime <= .0) //avoid setting time twice if track=level__loadingGen is scheduled for the next frame too
    level__allLoadedTime = get_sync_time()
  print("[Level loading Progress]\n\tlevelLoaded:\t{level__levelLoaded}\n\tgameObjectsCreated:\t{level__gameObjectsCreated}\n\tgameObjectsEntitiesCreated:\t{level__gameObjectsEntitiesCreated}\n\tmovingZoneAppeared:\t{level__movingZoneAppeared}\n\tmovingZoneInited:\t{level__movingZoneInited}\n\tnavmeshIslandsMarkerAppeared:\t{level__navmeshIslandsMarkerAppeared}\n\tnavmeshIslandsMarked:\t{level__navmeshIslandsMarked}\n\tlocalSceneEntitiesCreated:\t{level__localSceneEntitiesCreated}\n\tallLoadedTime:\t{level__allLoadedTime}")
  for e in level__retriggerEids
    sendEvent(e, EventRetriggerEntity())
  clear(level__retriggerEids)


[es(on_event=EventLevelLoaded)]
def level_loading_manager_level_loaded(evt : Event; var level__loadingGen : int&; var level__levelLoaded : bool&)
  level__levelLoaded = true
  level__loadingGen++


[es(on_event=EventGameObjectsCreated)]
def level_loading_manager_game_objects_created(evt : Event;
                                               level__hasNoGameObjects : bool;
                                               var level__loadingGen : int&;
                                               var level__gameObjectsCreated : bool&)
  if level__hasNoGameObjects
    logerr("Level marked as having no game objects but received EventGameObjectsCreated")
  level__gameObjectsCreated = true
  level__loadingGen++


[es(tag=netClient, track=level__gameObjectsEntitiesCreated)]
def level_loading_manager_update_gen_when_on_replicated_info(evt : Event; var level__loadingGen : int&; level__gameObjectsEntitiesCreated : bool)
  if level__gameObjectsEntitiesCreated
    level__loadingGen++


[es(on_appear, REQUIRE=moving_zone__targetPos)]
def level_loading_manager_moving_zone_appeared(evt : Event)
  find_query() <| $ [es] (var level__loadingGen : int&;
                          var level__movingZoneAppeared : bool&)
    level__movingZoneAppeared = true
    level__loadingGen++
    return true


[es(on_event=EventMovingZoneCreated)]
def level_loading_manager_moving_zone_inited(evt : Event; var level__loadingGen : int&; var level__movingZoneInited : bool&)
  level__movingZoneInited = true
  level__loadingGen++


[es]
def level_loading_manager_game_object_entities_scheduled(evt : EventGameObjectsEntitiesScheduled;
                                                         level__gameObjectEntitiesDone : int;
                                                         level__hasNoGameObjects : bool;
                                                         var level__loadingGen : int&;
                                                         var level__gameObjectEntitiesScheduled : int&;
                                                         var level__gameObjectsEntitiesCreated : bool&)
  if level__hasNoGameObjects
    logerr("Level marked as having no game objects but received EventGameObjectsEntitiesScheduled")
  print("[Level loading Progress] EventGameObjectsEntitiesScheduled {evt.count}")
  level__gameObjectEntitiesScheduled = evt.count
  if level__gameObjectEntitiesDone == level__gameObjectEntitiesScheduled
    level__gameObjectsEntitiesCreated = true
    level__loadingGen++


[es(on_appear, REQUIRE=gameObject)]
def level_loading_manager_game_object_entitiy_appeared(evt : Event; eid : EntityId)
  find_query() <| $ [es] (var level__loadingGen : int&;
                          var level__gameObjectsEntitiesCreated : bool&;
                          var level__gameObjectEntitiesDone : int&;
                          level__hasNoGameObjects : bool;
                          level__gameObjectEntitiesScheduled : int)
    if level__hasNoGameObjects
      logerr("Level marked as having no game objects but some were created: {getEntityTemplateName(eid)}")
    level__gameObjectEntitiesDone++
    if level__gameObjectEntitiesDone == level__gameObjectEntitiesScheduled
      level__gameObjectsEntitiesCreated = true
      level__loadingGen++
    return true


[es(tag=netClient, on_appear)]
def update_level_loading_manager_on_clieant(evt : Event;
                                            level__gameObjectsCreated : bool;
                                            var level__gameObjectsEntitiesCreated : bool&;
                                            var level__retriggerEids : EidList)
  level__gameObjectsEntitiesCreated = level__gameObjectsCreated //They will never be scheduled on the client
  clear(level__retriggerEids) //May contain server entities that we don't have access to


[es(on_appear, REQUIRE=level_without_game_objects)]
def set_level_loading_manager_no_game_objects(evt : Event)
  print("[Level loading Progress] Level marked as having no gameObjects")
  query() <| $ [es] (var level__gameObjectsCreated : bool&;
                     var level__gameObjectsEntitiesCreated : bool&;
                     var level__hasNoGameObjects : bool&;
                     var level__loadingGen : int&)
    level__gameObjectsEntitiesCreated = true
    level__gameObjectsCreated = true
    level__hasNoGameObjects = true
    level__loadingGen++


[es(on_appear, after=update_level_loading_manager_on_clieant)]
def set_level_loading_manager_no_game_objects2(evt : Event;
                                               var level__gameObjectsCreated : bool&;
                                               var level__gameObjectsEntitiesCreated : bool&;
                                               var level__hasNoGameObjects : bool&;
                                               var level__loadingGen : int&)
  query() <| $ [es(REQUIRE=level_without_game_objects)] ()
    print("[Level loading Progress] Level marked as having no gameObjects")
    level__gameObjectsEntitiesCreated = true
    level__gameObjectsCreated = true
    level__hasNoGameObjects = true
    level__loadingGen++


[es(on_event=EventNavmeshIslandsMarked)]
def level_loading_manager_nvmesh_marked(evt : Event;
                                        var level__loadingGen : int&;
                                        var level__navmeshIslandsMarked : bool&)
  level__navmeshIslandsMarked = true
  level__loadingGen++

[es(tag=server, on_appear, REQUIRE=navmesh_isle_marker)]
def register_navmesh_isle_marker(evt : Event)
  find_query() <| $ [es] (var level__loadingGen : int&;
                          var level__navmeshIslandsMarkerAppeared : bool&)
    level__navmeshIslandsMarkerAppeared = true
    level__loadingGen++
    return true


[es(on_event=EventOnLocalSceneEntitiesCreated)]
def level_loading_manager_local_entities_created(evt : Event)
  find_query() <| $ [es] (var level__loadingGen : int&;
                          var level__localSceneEntitiesCreated : bool&)
    level__localSceneEntitiesCreated = true
    level__loadingGen++
    return true