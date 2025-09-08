from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { TMatrix, Point2, cvt } = require("dagor.math")
let { sqrt } = require("math")
let { rnd_float } = require("dagor.random")
let { get_time_msec } = require("dagor.time")
let { get_transform } = require("%ui/helpers/common_queries.nut")
let { EventUpdateMonstrifyPosition } = require("dasevents")

let monstrifyTraps = Watched({})
let monstrifyTrapEids = Watched([])
let heroCanMonstrify = Watched(false)
let monstrifyVictimCircles = Watched({})


function deleteTrapByEid(eid) {
  monstrifyTraps.mutate(@(traps) traps.$rawdelete(eid))
  monstrifyTrapEids.mutate(function(traps) {
    local idx = traps.indexof(eid)
    if (idx != null)
      traps.remove(idx)
  })
}

ecs.register_es("monstrify_traps_state", {
  [[EventUpdateMonstrifyPosition]] = function(_evt, eid, comp) {
    {
      monstrifyTrapEids.mutate(@(v) v.append(eid))
      local transform = comp.transform
      if (transform == null) {
        transform = get_transform(comp.item__humanOwnerEid)
      }

      if (transform == null) {
        deleteTrapByEid(eid)
        return
      }

      monstrifyTraps.mutate(@(traps) traps[eid] <- {
        group = comp.monstrify_trap__group
        icon = comp.monstrify_trap__icon
        monsterName = comp.monstrify_trap__monsterName
        pos = transform[3]
      })
    }
  }
  onDestroy = function(eid, _comp) {
    deleteTrapByEid(eid)
  }
}, {
  comps_ro = [
    [ "monstrify_trap__group", ecs.TYPE_STRING ],
    [ "monstrify_trap__icon", ecs.TYPE_STRING ],
    [ "item__humanOwnerEid", ecs.TYPE_EID ],
    [ "monstrify_trap__monsterName", ecs.TYPE_STRING ],
    [ "transform", ecs.TYPE_MATRIX, null ]
  ]
}, {tags = "gameClient" })


ecs.register_es("monstrify_capability_state", {
  onInit = function(_eid, _comp) { heroCanMonstrify.set(true) }
  onDestroy = function(_eid, _comp) { heroCanMonstrify.set(false) }
}, {
  comps_rq = [
    [ "monstrify_capable", ecs.TYPE_TAG ],
    [ "watchedByPlr", ecs.TYPE_EID ]
  ]
}, {tags = "gameClient"})


let getDistanceSq = @(x, y) x * x + y * y
let getDistBetwenPoint = @(p1, p2) sqrt(getDistanceSq(p1.x - p2.x, p1.y - p2.y))
let victimZoneColor = Color(178, 34, 34)


let victimTransformQuery = ecs.SqQuery("victimTransformQuery", {
  comps_ro=[
    ["transform", ecs.TYPE_MATRIX],
    ["hunter_vision_target__fxDurationMult", ecs.TYPE_FLOAT]
  ],
  comps_rq=["hunter_vision_target__fxEid"],
  comps_no=["player_controlled_monster", "deadEntity"]
})


let hunterTransformQuery = ecs.SqQuery("hunterTransformQuery", {
  comps_ro=[["transform", ecs.TYPE_MATRIX]],
  comps_rq = ["watchedByPlr"]
})


ecs.register_es("monstrify_create_victim_list", {
  onInit = function(_eid, comp) {
    if (watchedHeroEid.get() != comp.game_effect__attachedTo)
      return
    let hunterTm = hunterTransformQuery.perform(comp.game_effect__attachedTo, @(_eid, compQ) compQ)?.transform ?? TMatrix()
    let hunterPos = Point2(hunterTm[3].x, hunterTm[3].z)
    let currTime = get_time_msec() * 0.001
    victimTransformQuery.perform(function (victimEid, victimComp) {
      let victimPos = Point2(victimComp.transform[3].x, victimComp.transform[3].z)
      let dist = getDistBetwenPoint(hunterPos, victimPos)
      let minMaxRadius = comp.ability_echolocation__mapRadiusRange
      let currRadius = cvt(dist, 50.0, 500.0, minMaxRadius.x, minMaxRadius.y)
      let rndOffset = Point2(rnd_float(-0.7, 0.7) * currRadius, rnd_float(-0.7, 0.7) * currRadius)
      let appearDisapperMult = 0.85
      let appearTime = comp.ability_echolocation__duration * (currRadius * 2 / (minMaxRadius.y + minMaxRadius.x))
      let maxAppearTime = comp.ability_echolocation__duration * (minMaxRadius.y * 2 / (minMaxRadius.y + minMaxRadius.x))
      monstrifyVictimCircles.mutate(@(victim) victim[victimEid] <- {
        pos = Point2(victimPos.x + rndOffset.x, victimPos.y + rndOffset.y)
        minMaxRadius = Point2(currRadius * appearDisapperMult, currRadius)
        currRadius = currRadius * appearDisapperMult
        color = Color(0, 0, 0)
        appearTime = appearTime
        startTime = currTime + (maxAppearTime - appearTime)
        
        
        endTime = currTime + (maxAppearTime - appearTime) + appearTime
      })
    })
  }
}, {
  comps_ro = [
    [ "ability_echolocation__mapRadiusRange", ecs.TYPE_POINT2 ],
    [ "ability_echolocation__duration", ecs.TYPE_FLOAT ],
    [ "game_effect__attachedTo", ecs.TYPE_EID ],
  ]
},
{tags = "gameClient"})


ecs.register_es("monstrify_set_end_time_to_victim_list", {
  onInit = function(_eid, comp) {
    if (watchedHeroEid.get() != comp.game_effect__attachedTo)
      return
    victimTransformQuery.perform(function (victimEid, victimComp) {
      if (victimEid not in monstrifyVictimCircles.get())
        return
      let timeNoise = comp.ability_echolocation__duration * victimComp.hunter_vision_target__fxDurationMult
      let currTime = get_time_msec() * 0.001
      monstrifyVictimCircles.mutate(function(victim) {
        victim[victimEid].endTime = currTime + timeNoise
        return victim
      })
    })
  }
}, {
  comps_ro = [
    [ "ability_echolocation__duration", ecs.TYPE_FLOAT ],
    [ "game_effect__attachedTo", ecs.TYPE_EID ],
  ],
  comps_rq = ["echolocation_affect"]
},
{tags = "gameClient"})


ecs.register_es("monstrify_update_victim_list", {
  onDestroy = @(_eid, _comp) monstrifyVictimCircles.set({})
  onUpdate = function(_eid, _comp) {
    let currTime = get_time_msec() * 0.001
    let keys = monstrifyVictimCircles.get().keys()
    monstrifyVictimCircles.mutate(function(victimCircles) {
      foreach (victimEid in keys) {
        local progress = -1.0
        if (currTime < victimCircles[victimEid].startTime + victimCircles[victimEid].appearTime) {
           progress = cvt(currTime,
            victimCircles[victimEid].startTime,
            victimCircles[victimEid].startTime + victimCircles[victimEid].appearTime,
            0.0,
            1.0)
        }
        else if (victimCircles[victimEid].endTime > 0.0  &&
          victimCircles[victimEid].endTime - victimCircles[victimEid].appearTime <= currTime) {
          progress = cvt(currTime,
            victimCircles[victimEid].endTime - victimCircles[victimEid].appearTime,
            victimCircles[victimEid].endTime,
            1.0,
            0.0)
          if (progress < 0.001) {
            victimCircles.$rawdelete(victimEid)
            continue
          }
        }
        else
          continue
        let currRadius = victimCircles[victimEid].minMaxRadius.x +
        victimCircles[victimEid].minMaxRadius.y * progress
        let color = mul_color(victimZoneColor, progress)
        victimCircles[victimEid].currRadius = currRadius
        victimCircles[victimEid].color = color
      }
      return victimCircles
    })
  }
}, {
  comps_rq = ["hero", "player_controlled_monster"]
}, {tags = "gameClient", updateInterval = 0.1, after="*", before="*" })


return {
    monstrifyTraps,
    monstrifyTrapEids,
    heroCanMonstrify,
    monstrifyVictimCircles
}
