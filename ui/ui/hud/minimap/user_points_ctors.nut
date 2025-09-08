from "%ui/ui_library.nut" import *

let { mkPointMarkerCtor, mkSpawnPointMarkerCtor } = require("components/minimap_markers_components.nut")

let markSz = [fsh(2), fsh(2.6)].map(@(v) v.tointeger())
let enMarkSz = [fsh(0.9), fsh(1.4)].map(@(v) v.tointeger())

let itemMarkSz = [fsh(0.75), fsh(0.75)]

let enemyBuildingMarkSz = [fsh(1.75), fsh(1.75)]

let mapSpawnMarkSz = [fsh(2), fsh(2)].map(@(v) v.tointeger())

let main_user_mark = Picture("!ui/skin#map_pin.svg:{0}:{1}:K".subst(markSz[0],markSz[1]))
let enemy_user_mark = Picture("!ui/skin#unit_inner.svg:{0}:{1}:K".subst(enMarkSz[0],enMarkSz[1]))
let map_spawn_mark = Picture("!ui/skin#teleportation-of-human.svg:{0}:{1}:K".subst(mapSpawnMarkSz[0],mapSpawnMarkSz[1]))
let user_points_ctors = {
  main_user_point = mkPointMarkerCtor({
    image = main_user_mark,
    colors = {myHover = Color(250,250,180,250), myDef = Color(255, 200, 50, 220), foreignHover = Color(220,220,250,250), foreignDef = Color(180,180,250,250)}
    size = markSz
  })

  map_spawn_point = mkSpawnPointMarkerCtor({
    image = map_spawn_mark,
    colors = {myHover = Color(250,250,180,250), myDef = Color(255, 200, 50, 220), foreignHover = Color(220,220,250,250), foreignDef = Color(180,180,250,250)}
    size = mapSpawnMarkSz
    valign = ALIGN_CENTER
  })

  enemy_user_point = mkPointMarkerCtor({
    image = enemy_user_mark,
    colors = {myHover = Color(250,200,200,250), myDef = Color(250,50,50,250), foreignHover = Color(220,180,180,250), foreignDef = Color(200,50,50,250)}
    size = enMarkSz
  })

  item_user_point = mkPointMarkerCtor({
    image = enemy_user_mark,
    colors = {myHover = Color(250,250,180,250), myDef = Color(255, 200, 50, 220), foreignHover = Color(220,220,250,250), foreignDef = Color(180,180,250,250)}
    size = itemMarkSz
  })

  enemy_building_user_point = mkPointMarkerCtor({
    colors = {myHover = Color(250,200,200,250), myDef = Color(250,50,50,250), foreignHover = Color(220,180,180,250), foreignDef = Color(200,50,50,250)}
    valign = ALIGN_CENTER
    size = enemyBuildingMarkSz
  })
}

let mkUserPoints = @(ctors, state) {
  watch = state
  function ctor(p) {
    let res = []
    foreach(eid, info in state.get())
      res.append(ctors?[info.type](eid, info, p))

    return res
  }
}

return {
  user_points_ctors
  mkUserPoints
}
