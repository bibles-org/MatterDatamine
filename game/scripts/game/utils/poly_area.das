module poly_area shared
require pathfinder

enum AMPolyArea : uint8
  // common areas @see PolyArea
  POLYAREA_UNWALKABLE = pathfinder::POLYAREA_UNWALKABLE // 0
  POLYAREA_GROUND = pathfinder::POLYAREA_GROUND // 1
  POLYAREA_OBSTACLE = pathfinder::POLYAREA_OBSTACLE // 2
  POLYAREA_JUMP = pathfinder::POLYAREA_JUMP // 5

  // am specific areas
  POLYAREA_DANGER = 6
  POLYAREA_WALKABLE_ISLE = 31

  // system area
  POLYAREA_WALKABLE = pathfinder::POLYAREA_WALKABLE // 63u
