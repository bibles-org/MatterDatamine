from "dasevents" import EventShowHitMark
from "math" import cos, sin, PI

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs


let hitTtl = 1.2 
let killTtl = 1.8 

let hitmarksWidth = hdpx(1.8)
let hitSize = [fsh(3.5),fsh(3.5)]
let killSize = [fsh(3.8),fsh(3.8)]
let hitColor = Color(100, 100, 100, 50)
let killColor = Color(160, 100, 100, 60)
let currentHitMarks = Watched()

local hitmarkIdx = 1
let clearHitMarker = @() currentHitMarks.set(null)

ecs.register_es("ui_hit_marks_es", {
    [EventShowHitMark] = function(evt, _eid, _comp) {
      hitmarkIdx++
      currentHitMarks.set({key = hitmarkIdx, isKill = evt.isKill, position = evt.position})
      gui_scene.resetTimeout(hitTtl, clearHitMarker)
    },
    onDestroy = @(...) currentHitMarks.set(null)
  }, { comps_rq=["watchedByPlr"] }
)

function mkAnimations(duration=0.4, appearPart = 0.15, stayPart = 0.25, fadePart = 0.65){
  duration = min(duration, 100)
  let appearDur = appearPart*duration
  let stayDur = stayPart*duration
  let fadeDur = fadePart*duration
  let fadeOutTrigger = {}
  let fadedTrigger = {}
  return freeze([
    { prop=AnimProp.opacity, from=0.1, to=1.0, duration=appearDur, play=true, easing=InCubic, onExit=fadeOutTrigger }
    { prop=AnimProp.opacity, from=1.0, to=0.0, delay = stayDur, duration=fadeDur, easing = InCubic, trigger=fadeOutTrigger, onExit=fadedTrigger }
    { prop=AnimProp.opacity, from=0.0, to=0.0, duration=100000, trigger=fadedTrigger } 
  ])
}

function build_hitmarks_commands(marksCount, percentile = 0.6) {
  let commands = [[VECTOR_WIDTH, hitmarksWidth]]
  let markSize = 100
  let initAngle = PI * 0.5 / (marksCount + 1);
  let center = {
    x = 50
    y = 50
  }
  for (local markId = 0; markId < marksCount; ++markId) {
    
    for (local i = 0; i < 2; ++i) {
      let angle = initAngle*(markId + 1) - PI*0.5*i
      let c = cos(angle)
      let s = sin(angle)
      for (local j = -1; j <= 1; j += 2) {
        let coor = {
          x = markSize * c * j
          y = markSize * s * j
        }
        commands.append([VECTOR_LINE,
          center.x + coor.x * percentile, center.y + coor.y * percentile,
          center.x + coor.x, center.y + coor.y])
      }
    }
  }
  return commands
}

let hitMark = build_hitmarks_commands(1)
let killMark = build_hitmarks_commands(1, 0.5)

let commonHitMarkAnims = mkAnimations(hitTtl/3.0) 
let commonKillMarkAnims = mkAnimations(killTtl/3.0)
let hitMarkParam = freeze({size = hitSize, color = hitColor, animations = commonHitMarkAnims, commands = hitMark rendObj = ROBJ_VECTOR_CANVAS transform = {} })
let killMarkParam = freeze({size = killSize, color = killColor, animations = commonKillMarkAnims, commands = killMark rendObj = ROBJ_VECTOR_CANVAS transform = {} })

let watchHitMarks = freeze({watch = currentHitMarks})

function hits() {
  if (currentHitMarks.get() == null)
    return watchHitMarks
  let { key, isKill, position } = currentHitMarks.get()
  return {
    watch = currentHitMarks
    behavior = DngBhv.Projection
    size = flex()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = {
      key,
      data = {
        minDistance = 0.0
        worldPos = position
      }
      transform = {}
    }.__update(isKill ? killMarkParam : hitMarkParam)
  }
}


let hit_marks = {
  size = flex()
  children = hits
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
}

return {
  hit_marks
}