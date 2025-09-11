from "%sqstd/math.nut" import truncateToMultiple
from "%ui/helpers/timers.nut" import mkCountdownTimer
from "%ui/components/colors.nut" import TextDisabled, GreenSuccessColor, RedWarningColor
from "%ui/components/commonComponents.nut" import mkTooltiped, mkText
from "dasevents" import EventStartThrowStone, EventHumanFall, EventEntityDied, CmdShowPoisonEffect, CmdShowHealOverTimeEffect
from "net" import get_sync_time
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/tooltipBox.nut" as tooltipBox
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "math" import PI, sin, cos, min, tan, abs, sqrt

let { get_controlled_hero } = require("%dngscripts/common_queries.nut")
let { playerMovePenalty, inventoryCurrentWeight } = require("%ui/hud/state/inventory_state.nut")
let { levelLoaded, isInBattleState } = require("%ui/state/appState.nut")
let { watchedHeroSneaking } = require("%ui/hud/state/watched_hero.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")

let positiveStyle = freeze({
  fgColor = mul_color(GreenSuccessColor, 0.7)
  bgColor = TextDisabled
})

let negativeStyle = freeze({
  fgColor = mul_color(RedWarningColor, 0.7)
  bgColor = TextDisabled
})

let timeEffectsGen = Watched(0)

let poison = Watched(null)
let poisonProto  = freeze({
  icon = "ui/skin#poison_effect.svg"
  tip = "effects/poison_effect"
  style = negativeStyle
})
ecs.register_es("track_poison_effect",
  {
    [CmdShowPoisonEffect] = function(evt, _eid, _comp) {
      let startTime = evt.begin
      let endTime = evt.end
      poison.set(poisonProto.__merge({startTime, endTime, duration = endTime-startTime}))
    }
  },
  {
    comps_rq = ["watchedByPlr"]
  }
)

let healOverTime = Watched(null)
let healProto = freeze({
  icon = "ui/skin#regeneration.svg"
  tip = "effects/healing_over_time"
  style = positiveStyle
})

ecs.register_es("track_healing_over_time_effect",
  {
    [ CmdShowHealOverTimeEffect ] = function(evt, _eid, _comp) {
      healOverTime.set(healProto.__merge({
        duration = evt.end - evt.begin
        startTime = evt.begin
        endTime = evt.end
      }))
    }
  },
  {
    comps_rq = ["watchedByPlr"]
  }
)

let painkillerEffect = Watched(null)
let painProto = freeze({
  icon = "ui/skin#painkiller.svg"
  tip = "effects/painkiller"
  style = positiveStyle
})

console_register_command(function() {
 let ct = get_sync_time()
 const duration = 2000
 painkillerEffect.set(painProto.__merge({
   startTime = ct
   endTime = duration + ct
   duration
 }))
}, "debug.painkiller_effect")

ecs.register_es("track_painkiller_effect",
  {
    onInit = function(_eid, comp) {
      if (get_controlled_hero() != comp.game_effect__attachedTo)
        return
      painkillerEffect.set(painProto.__merge({
        duration = comp.game_effect__timeToDestroy
        startTime = get_sync_time()
        endTime = comp.game_effect__destroyAt
      }))
    }
    onDestroy = @(...) painkillerEffect.set(null)
  },
  {
    comps_ro = [
      ["game_effect__destroyAt", ecs.TYPE_FLOAT],
      ["game_effect__timeToDestroy", ecs.TYPE_FLOAT],
      ["game_effect__attachedTo", ecs.TYPE_EID],
    ],
    comps_rq = [["painkillerEffect", ecs.TYPE_TAG]]
  }
)

let throwStonesCooldown = Watched(null)
let throwStonesProto = freeze({
  icon = "ui/skin#stone_cooldown.svg"
  tip = "effects/throw_stones_cooldown"
  style = negativeStyle
})
ecs.register_es("track_throw_stones_cooldown_effect",
  {
    [[EventStartThrowStone]] = function(_eid, comp) {
      let startTime = get_sync_time()
      let duration = comp.human_stone_throw__throwCooldown

      throwStonesCooldown.set(throwStonesProto.__merge({startTime, duration, endTime = startTime + duration}))
    }
  },
  {
    comps_ro = [
      ["human_stone_throw__throwTimer", ecs.TYPE_FLOAT],
      ["human_stone_throw__throwCooldown", ecs.TYPE_FLOAT],
    ],
    comps_rq = [["watchedByPlr", ecs.TYPE_EID]]
  }
)


let abilitiesCooldown = Watched({})

ecs.register_es("track_abilities_cooldown_effect",
  {
    onDestroy = @(...) abilitiesCooldown.set({}),
    [["onChange","onInit"]] = function(_evt, _eid, comp) {
      foreach (ability in comp.hero_ability__abilities) {
        let abilityName = ability.name

        let endTime = comp.hero_ability__abilitiesNextUseTime?[abilityName] ?? 0.0
        let cooldown = comp.hero_ability__abilitiesCooldown?[abilityName] ?? 0.0
        let startTime = endTime - cooldown
        let icon = ability?.icon ? $"!ui/{ability?.icon}": ""
        let name = ability?.name ?? "ability"
        abilitiesCooldown.mutate(@(v) v[abilityName] <- {
          icon
          tip = "effects/ability_cooldown"
          style = negativeStyle
          duration = cooldown
          startTime
          endTime
          name
        })
      }
    }
  },
  {
    comps_track = [
      ["hero_ability__abilitiesNextUseTime", ecs.TYPE_OBJECT]
    ]
    comps_ro = [
      ["hero_ability__abilitiesCooldown", ecs.TYPE_OBJECT],
      ["hero_ability__abilities", ecs.TYPE_ARRAY]
    ],
    comps_rq = [["watchedByPlr", ecs.TYPE_EID]]
  }
)

let humanFallEffect = Watched(null)
let fallProto = freeze({
  icon = "ui/skin#distress.svg"
  tip = "effects/human_fall"
  style = negativeStyle
})
ecs.register_es("track_human_fall_effect",
  {
    [[EventHumanFall]] = function(evt, _eid, _comp) {
      let startTime = get_sync_time()
      let duration = evt.duration
      humanFallEffect.set(fallProto.__merge({startTime, duration, endTime = startTime+duration}))
    }
  },
  {
    comps_rq = [
      ["watchedByPlr", ecs.TYPE_EID],
    ]
  }
)

ecs.register_es("clear_ui_affects",
  {
    [["onDestroy", EventEntityDied]] = function(_evt, _eid) {
      healOverTime.set(null)
      painkillerEffect.set(null)
      throwStonesCooldown.set(null)
      abilitiesCooldown.set({})
      humanFallEffect.set(null)
      poison.set(null)
    }
  },
  {
    comps_rq = [
      ["watchedByPlr", ecs.TYPE_EID],
    ]
  }
)


let statusWidth = hdpxi(40)
let iconWidth = (statusWidth / 1.5).tointeger()

let iconBackground = {
  commands = [
    [VECTOR_FILL_COLOR, Color(0,0,0,80)],
    [VECTOR_COLOR, Color(0,0,0,0)],
    [VECTOR_WIDTH, 0],
    [VECTOR_ELLIPSE, 50, 50, 50, 50],
  ]
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
}

function mkInventoryIcon(data, countdown){
  let dur = data?.duration ?? 0
  if (data == null || dur <= 0)
    return null
  return mkTooltiped({
    size = statusWidth
    margin = static [hdpx(5), 0, hdpx(5), 0]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      iconBackground
      {
        size = iconWidth
        rendObj = ROBJ_IMAGE
        image = Picture($"{data.icon}:{iconWidth}:{iconWidth}:P")
      }
     dur > 0 ? @() {
        size = flex()
        watch = countdown
        rendObj = ROBJ_PROGRESS_CIRCULAR
        image = Picture($"ui/skin#round_border.svg:{statusWidth}:{statusWidth}:P")
        fgColor = data.style.fgColor
        bgColor = data.style.bgColor
        fValue = countdown.get() / data.duration
      } : null
    ]
  }, tooltipBox(@() {
    watch = countdown
    children = mkText(loc(data.tip, { duration = truncateToMultiple(countdown.get(), 1)}))
  }))
}

function mkOverweightIndicator(weight, movePenalty, needTooltip, alwaysVisible, skipDirPadNav) {
  let noOverweight = 30
  let lightOverweight = 50

  if (weight < noOverweight && !alwaysVisible)
    return null

  return {
    size = [statusWidth, statusWidth]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    margin = static [hdpx(5), 0, hdpx(5), 0]
    skipDirPadNav
    behavior = needTooltip ? Behaviors.Button : null
    onHover = @(on) setTooltip(on ? loc("inventory/weightPenalty", { value = (movePenalty * 100).tointeger() }) : null)

    children = [
      iconBackground
      {
        rendObj = ROBJ_IMAGE
        size = [ iconWidth, iconWidth ]
        color = weight < noOverweight ? Color(101, 101, 101, 255) :
          weight < lightOverweight ? Color(253, 183, 51, 255) :
          Color(228, 72, 68, 255)
        image = Picture($"!ui/skin#overweight.svg:{iconWidth}:{iconWidth}:K")
      }
    ]
  }
}

let overweight = @(needTooltip = false, alwaysVisible = false) function() {
  if (!levelLoaded.get())
    return { watch = levelLoaded }
  return {
    watch = [levelLoaded, playerMovePenalty, inventoryCurrentWeight, isInBattleState]
    children = mkOverweightIndicator(inventoryCurrentWeight.get(), playerMovePenalty.get(),
      needTooltip, alwaysVisible, isInBattleState.get())
  }
}

let sneakIndicator = @() {
  watch = hudIsInteractive
  children = mkTooltiped(@() {
    size = [ statusWidth, statusWidth ]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    margin = static [hdpx(5), 0, hdpx(5), 0]
    children = [
      iconBackground
      {
        rendObj = ROBJ_IMAGE
        size = [ iconWidth, iconWidth ]
        image = Picture($"!ui/skin#player_sneak_indicator.avif:{iconWidth}:{iconWidth}:K")
      }
    ]
  },
  loc("inventory/walkIndicator"),
  { behavior = hudIsInteractive.get() ? Behaviors.Button : null })
}

let activeEffects = Computed(function() {
  let effectsWatched = freeze([timeEffectsGen, healOverTime, painkillerEffect, throwStonesCooldown,
    
    humanFallEffect, poison])
  let ctime = get_sync_time()
  return effectsWatched
    .map(@(w) w.get())
    .extend(abilitiesCooldown.get().values())
    .filter(@(w) (w?.endTime ?? 0) > ctime)
    .sort(@(a, b) (a?.startTime ?? 0) <=> (b?.startTime ?? 0))
})

let inventoryEffectsWithTimer = @() {
  watch = activeEffects
  flow = FLOW_HORIZONTAL
  gap = static hdpx(5)
  children = activeEffects.get().map(function(w) {
    let { endTime, tip = "", name = null } = w
    let countdown = mkCountdownTimer(Watched(endTime), $"inv_{name ?? tip}")
    let needToShow = Computed(@() countdown.get() > 0)
    return @() {
      watch = needToShow
      children = needToShow.get() ? mkInventoryIcon(w, countdown) : null
    }
  })
}

let additionalInventoryEffects = @() {
  watch = [watchedHeroSneaking, inventoryCurrentWeight, isInBattleState, hudIsInteractive]
  flow = FLOW_HORIZONTAL
  gap = static hdpx(5)
  children = [
    overweight(hudIsInteractive.get(), true)
    watchedHeroSneaking.get() ? sneakIndicator : null
  ].filter(@(v) v != null)
}

function inventoryAffectsWidget() {
  return {
    vplace = ALIGN_TOP
    hplace = ALIGN_LEFT
    pos = [0, hdpx(60)] 
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = [
      additionalInventoryEffects
      inventoryEffectsWithTimer
    ]
  }
}

let phi0 = 5 * PI / 6
let sector = PI / 9
let offset = hdpx(45)
function mkOffsetContainer(idx, radius, content) {
  let x = radius * cos(phi0 + sector * idx)
  let y = -radius * sin(phi0 + sector * idx)
  return {
    pos = [x, y]
    children = content
  }
}

function mkWatchfaceIcon(data, countdown){
  if (data == null || (data?.duration ?? 0) <= 0)
    return null
  return {
    size = [ statusWidth, statusWidth ]
    margin = static [hdpx(5), 0, hdpx(5), 0]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      iconBackground
      {
        size = [ iconWidth, iconWidth ]
        rendObj = ROBJ_IMAGE
        image = Picture($"{data.icon}:{iconWidth}:{iconWidth}:P")
      }
      @() {
        size = flex()
        watch = countdown
        rendObj = ROBJ_PROGRESS_CIRCULAR
        image = Picture($"ui/skin#round_border.svg:{statusWidth}:{statusWidth}:P")
        fgColor = data.style.fgColor
        bgColor = data.style.bgColor
        fValue = countdown.get() / data.duration
      }
    ]
  }
}

function mkEffectWithTimer(w, idx, radius=null) {
  let { endTime, tip = "", name = null } = w
  let countdown = mkCountdownTimer(Watched(endTime), name ?? tip)
  let needToShow = Computed(@() countdown.get() > 0)
  return function() {
    if (!needToShow.get())
      timeEffectsGen.modify(@(v) v + 1)
    return {
      watch = needToShow
      children = !needToShow.get() ? null
        : radius == null ? mkWatchfaceIcon(w, countdown)
        : mkOffsetContainer(idx, radius + offset, mkWatchfaceIcon(w, countdown) )
    }
  }
}

let mkEffectsWithTimer = @(radius = null) @() {
  watch = activeEffects
  children = activeEffects.get().map(@(w, idx) mkEffectWithTimer(w, idx, radius))
}.__merge(radius != null ? {} : { flow = FLOW_VERTICAL })

let mkAdditionalEffects = @(radius = null) @() {
  watch = [watchedHeroSneaking, inventoryCurrentWeight, isInBattleState, activeEffects, playerMovePenalty]
  children = [
    mkOverweightIndicator(inventoryCurrentWeight.get(), playerMovePenalty.get(), false, false, isInBattleState.get())
    watchedHeroSneaking.get() ? sneakIndicator : null
  ]
    .filter(@(v) v != null)
    .map(@(v, idx) radius == null ? v : mkOffsetContainer(activeEffects.get().len() + idx, radius + offset, v))
}.__merge(radius != null ? {} : { flow = FLOW_VERTICAL })

let mkWatchfaceAffectsWidget = @(radius) function() {
  return {
    size = [2 * radius + offset, 2 * radius + offset]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      mkEffectsWithTimer(radius)
      mkAdditionalEffects(radius)
    ]
  }
}

let affectsWidget = @() {
  flow = FLOW_VERTICAL
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  children = [
    mkEffectsWithTimer()
    mkAdditionalEffects()
  ]
}


return {
  affectsWidget
  inventoryAffectsWidget
  mkWatchfaceAffectsWidget
  mkEffectWithTimer
  mkInventoryIcon
  negativeStyle
}
