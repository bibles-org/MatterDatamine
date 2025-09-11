import "%dngscripts/ecs.nut" as ecs
import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker

from "%ui/ui_library.nut" import *
from "%ui/hud/state/watched_hero.nut" import watchedHeroEid, watchedHeroPlayerEid
from "%ui/components/colors.nut" import TeammateColor
from "%ui/squad/squad_colors.nut" import orderedTeamNicks
from "%sqGlob/dasenums.nut" import RobodogState

let robodogEids = Watched({})

let player_get_name_query = ecs.SqQuery("player_get_name_query", {
  comps_ro = [["name", ecs.TYPE_STRING]]
})

let hero_get_team_query = ecs.SqQuery("hero_get_team_query", {
  comps_ro = [["team", ecs.TYPE_INT]]
})

function onRobodogAppear(eid, comp) {
  let localTeam = hero_get_team_query.perform(watchedHeroEid.get(), @(_eid, heroComp) heroComp.team)
  if (localTeam == comp.team) {
    let teammateName = player_get_name_query.perform(comp.playerOwnerEid, @(_eid, playerComp) playerComp.name)
    let colorIdx = orderedTeamNicks.get().findindex(@(v)v == teammateName) ?? 0
    local color = TeammateColor[colorIdx]
    local status = "robodog/followsTeammate"
    if (watchedHeroPlayerEid.get() == comp.playerOwnerEid)
      status = "robodog/followsYou"
    let ownerName = teammateName
    if (!comp.isAlive) {
      color = Color(228, 72, 68)
      status = "robodog/broken"
    }
    else if (comp.robodog__currentState == RobodogState.PRONE) {
      color = Color(230, 230, 230)
      status = "robodog/deactivateTeammate"
      if (watchedHeroPlayerEid.get() == comp.playerOwnerEid)
        status = "robodog/deactivate"
    }
    robodogEids.mutate(@(v) v[eid] <- {
      color = color
      status = status
      ownerName = ownerName
    })
  }
  else
    robodogEids.mutate(@(v) v.$rawdelete(eid))
}

ecs.register_es("map_robodog_es", {
  [["onInit", "onChange"]] = onRobodogAppear
  onDestroy = @(eid, _comp) robodogEids.mutate(@(v) v.$rawdelete(eid))
}, {
  comps_rq = [],
  comps_track = [["robodog__currentState", ecs.TYPE_INT],
                 ["isAlive", ecs.TYPE_BOOL],
                 ["playerOwnerEid", ecs.TYPE_EID],
                 ["ownerEid", ecs.TYPE_EID],
                 ["team", ecs.TYPE_INT]]
})

let robodogsQuery = ecs.SqQuery("map_robodog_ui_query", {
  comps_ro = [["robodog__currentState", ecs.TYPE_INT],
              ["isAlive", ecs.TYPE_BOOL],
              ["playerOwnerEid", ecs.TYPE_EID],
              ["ownerEid", ecs.TYPE_EID],
              ["team", ecs.TYPE_INT]]
})

watchedHeroEid.subscribe_with_nasty_disregard_of_frp_update(function(_) {
  robodogEids.set({})
  robodogsQuery.perform(onRobodogAppear)
})

function mkRobodogMark(data) {
  let robodogList = data.keys()
  return robodogList.map(function(eid) {
    return mapHoverableMarker(
      {eid, clampToBorder = false}
      {},
      loc(data[eid].status, {nickname = data[eid].ownerName}),
      @(_) {
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        rendObj = ROBJ_IMAGE
        image = Picture($"ui/skin#robodog.svg:{hdpxi(16)}:{hdpxi(16)}:P")
        color = data[eid].color
        size = hdpxi(16)
      }
    )
  })
}

return {
  robodogMarks = {
    watch = robodogEids
    ctor = @(_) mkRobodogMark(robodogEids.get())
  }
}
