module pathfinder_utils_common shared
require ecs
require pathfinder
require game.events.events_active_matter


def process_tilecache_sync()
  broadcastEventImmediate(EventTilecacheSyncWillBeStarted())
  tilecache_sync()
  broadcastEvent(EventTilecacheSyncFinished())