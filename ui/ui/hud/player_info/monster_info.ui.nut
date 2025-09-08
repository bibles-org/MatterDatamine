import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { TextNormal, RedWarningColor, OrangeHighlightColor, BtnBgActive, TextDisabled,
      BtnBdHover, BtnBdFocused } = require("%ui/components/colors.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let hideHud = require("%ui/hud/state/hide_hud.nut")
let { isInMonsterState } = require("%ui/hud/state/hero_monster_state.nut")
let { fullHp, curHp } = require("%ui/hud/state/human_damage_model_state.nut")
let mkStraightCompassStrip = require("%ui/hud/compass/mk_straight_compass_strip.nut")
let corticalVaultCompassItems = require("%ui/hud/compass/compass_cortical_vault.nut")
let teammatesCompass = require("%ui/hud/compass/compass_teammates.nut")
let { screamAvailableCount, screamMaxCount,
  SCREAM_ABILITY_NAME } = require("%ui/hud/state/dash_ability_state.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { mkCountdownTimer } = require("%ui/helpers/timers.nut")
let { controlHudHint } = require("%ui/components/controlHudHint.nut")
let { AbilityUseFailed, AbilityUseFailedClient } = require("dasevents")
let { AbilityUseFailedReason } = require("%sqGlob/dasenums.nut")
let { body_txt } = require("%ui/fonts_style.nut")
let { debounceImmediate } = require("%sqstd/timers.nut")

const MONSTER_ANIM_TRIGGER = "monsterBorderAnim"

let monsterCompass = mkStraightCompassStrip([corticalVaultCompassItems, teammatesCompass], 0.8)

let maxStamina = Watched(-1)
let currentStamina = Watched(-1)

let iconSize = hdpxi(16)
let vitalityLineHeight = hdpx(10)
let vitalityLineSize = [hdpx(150), vitalityLineHeight]

let abilitiesCooldown = Watched({})
let abilitiesNextUse = Watched({})
let abilitiesInfo = Watched({})
let hintWasShown = {}

ecs.register_es("current_ability_ui_es", {
    [["onInit", "onChange"]] = function(_evt, _eid, comp) {
      let abilities = (comp?.hero_ability__abilities.getAll() ?? {}).filter(@(a) !(a?.device_ability ?? false) && (a?.show_in_ui ?? true) && a?.name!=null && a?.type!="passive")
      abilitiesInfo.set(abilities)
      foreach (a in abilities)
        if (a.name not in hintWasShown)
          hintWasShown[a.name] <- false
      abilitiesCooldown.set(comp?.hero_ability__abilitiesCooldown.getAll() ?? {})
      abilitiesNextUse.set(comp?.hero_ability__abilitiesNextUseTime.getAll() ?? {})
    }
    onDestroy = function(...) {
      abilitiesCooldown.set({})
      abilitiesNextUse.set({})
      abilitiesInfo.set({})
      hintWasShown.clear()
    }
  },
  {
    comps_track=[["hero_ability__abilitiesNextUseTime", ecs.TYPE_OBJECT]],
    comps_ro = [["hero_ability__abilities", ecs.TYPE_ARRAY], ["hero_ability__abilitiesCooldown", ecs.TYPE_OBJECT]]
    comps_rq=["watchedByPlr","monster_ability"]
  }
)

let abilitiesCharges = freeze({
  [SCREAM_ABILITY_NAME] = {
    maxWatched = screamMaxCount
    curWatched = screamAvailableCount
  }
})

let anim_start_debounced = debounceImmediate(anim_start, 0.3)
ecs.register_es("track_ability_fail_es", {
  [[AbilityUseFailed, AbilityUseFailedClient]] = function(evt, _eid, _comp) {
      let { ability_name = null, reason = -1 } = evt
      if (ability_name == null)
        return
      anim_start_debounced($"failed_{ability_name}")

      if (reason == AbilityUseFailedReason.NOT_ENOUGH_STAMINA)
        anim_start_debounced($"failed_ability_not_enough_stamina")
    }
  },
  {
    comps_rq = [["hero", ecs.TYPE_TAG]],
  },
  { tags = "gameClient" })


let gatherStonesAblityCurStones = Watched(null)
ecs.register_es("track_floating_objects_num",
  {
    [["onChange", "onInit"]] = function(_eid, comp) {
      gatherStonesAblityCurStones.set(comp.floating_objects__numObjects)
    }
    onDestroy = @(...) gatherStonesAblityCurStones.set(null)
  },
  {
    comps_track = [["floating_objects__numObjects", ecs.TYPE_INT]]
    comps_rq = ["watchedByPlr"]
  }
)

ecs.register_es("monster_flight_stamina_ui_es",
  {
    [["onInit", "onChange"]] = function(_eid, comp) {
      maxStamina.set(comp?.monster_flight_mode__maxStamina ?? 100)
      currentStamina.set(comp?.monster_flight_mode__stamina ?? 100)
    }
    onDestroy = @(...) function() {
      maxStamina.set(-1)
      currentStamina.set(-1)
    }
  },
  {
    comps_track=[
      ["monster_flight_mode__maxStamina", ecs.TYPE_FLOAT],
      ["monster_flight_mode__stamina", ecs.TYPE_FLOAT]
    ],
    comps_rq = ["watchedByPlr"]
  }
)

ecs.register_es("monster_dash_stamina_ui_es",
  {
    [["onInit", "onChange"]] = function(_eid, comp) {
      maxStamina.set(comp?.dash__maxStamina ?? 100)
      currentStamina.set(comp?.dash__stamina ?? 100)
    }
    onDestroy = @(...) function() {
      maxStamina.set(-1)
      currentStamina.set(-1)
    }
  },
  {
    comps_track = [["dash__stamina", ecs.TYPE_FLOAT]]
    comps_ro = [["dash__maxStamina", ecs.TYPE_FLOAT]]
    comps_rq = ["watchedByPlr"]
  }
)

function monsterCompassBlock() {
  let watch = [isInMonsterState, hideHud]
  if (!isInMonsterState.get() || hideHud.get())
    return { watch }
  return {
    watch
    rendObj = ROBJ_WORLD_BLUR_PANEL
    margin = hdpx(20)
    children = monsterCompass
  }
}

let disabled_watch = [isInMonsterState, hideHud]
let full_watch = [isInMonsterState, hideHud, fullHp, curHp]
let dangerColors = [Color(160,159,159,100), Color(255,120,120,100), Color(255,80,80,80), Color(235,20,20,120)]
let dangerAnims = freeze([
  null,
  [{prop = AnimProp.color, from=dangerColors[1], to=dangerColors[0] loop = true play=true duration=3 easing=CosineFull}],
  [{prop = AnimProp.color, from=dangerColors[2], to=dangerColors[1] loop = true play=true duration=1.0 easing=CosineFull}],
  [{prop = AnimProp.color, from=dangerColors[3], to=dangerColors[2] loop = true play=true duration=0.5 easing=CosineFull}],
])

console_register_command(@(hp) curHp.set(hp), "hud.hp_debug_set",)
console_register_command(function(stamina_percent) {
  maxStamina.set(100.0)
  currentStamina.set(stamina_percent.tofloat())
}, "hud.stamina_debug_set")

let progressback = freeze({
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = flex()
  fillColor = Color(0,0,0,50)
  borderWidth = hdpx(1)
  borderColor = Color(40,40,40,10)
})

let dummyVitalityLine = {
  size = vitalityLineSize
}

let staminaAnimations = [
  {
    prop = AnimProp.color, from = BtnBdFocused, to = RedWarningColor, easing = CosineFull,
    duration = 0.3, trigger = "failed_ability_not_enough_stamina"
  }
]

function vitalityBlock() {
  let needShowStaminaBlock = Computed(@() currentStamina.get() < maxStamina.get())
  return function() {
    let watch = [isInMonsterState, hideHud, maxStamina, needShowStaminaBlock]
    if (!isInMonsterState.get() || hideHud.get() || maxStamina.get() <= 0)
      return { watch }
    return {
      watch
      valign = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      gap = hdpx(6)
      size = [ SIZE_TO_CONTENT, iconSize ]
      children = needShowStaminaBlock.get() ? [
        {
          halign = ALIGN_RIGHT
          size = vitalityLineSize
          children = [
            progressback
            @() {
              watch = [ currentStamina, maxStamina ]
              rendObj = ROBJ_SOLID
              size = [pw((currentStamina.get() / maxStamina.get() * 100).tointeger()), flex()]
              color = BtnBdFocused
              transform = {}
              animations = staminaAnimations
            }
          ]
        }
        {
          rendObj = ROBJ_IMAGE
          size = [ iconSize, iconSize ]
          image = Picture($"ui/skin#stamina_arrow.svg:{iconSize}:{iconSize}:P")
        }
      ] : null
    }
  }
}

function healthBlock() {
  if (!isInMonsterState.get() || hideHud.get())
    return { watch = disabled_watch}
  let hp = curHp.get()
  let max_hp = fullHp.get()
  let percentage = hp != null && max_hp !=null ? (hp*100.0/max_hp).tointeger() : 100
  let dangerLevel = percentage >= 100
    ? 0
    : percentage > 66
      ? 1
      : percentage >= 25 ? 2 : 3
  let color = dangerColors?[dangerLevel]
  let animations = dangerAnims?[dangerLevel]
  return {
    watch = full_watch
    size = vitalityLineSize
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = hdpx(6)
    children = percentage == 100 ? dummyVitalityLine : [
      {
        size = flex()
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        children = [
          progressback
          {
            rendObj = ROBJ_SOLID
            size = [pw(percentage), flex()]
            key = dangerLevel, animations, color
          }
        ]
      }
    ]
  }
}

let monsterDollBlock = {
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    healthBlock
    vitalityBlock()
  ]
}
let mkAbilityAnimations = memoize(@(name) freeze([
  {
    prop = AnimProp.fillColor, fillColor = 0x00000000, to = BtnBgActive, easing = CosineFull,
    duration = 0.5, trigger = $"{MONSTER_ANIM_TRIGGER}_{name}"
  }
  {
    prop = AnimProp.borderColor, fillColor = 0x00000000, to = RedWarningColor, easing = CosineFull,
    duration = 0.3, trigger = $"failed_{name}"
  }
]))

function mkAbilityCtor(abilityInfo, content = null, cooldown=0) {
  let { name = null } = abilityInfo
  let tooltip = name != null ? loc($"{name}/desc", {cooldown}) : null
  return watchElemState(@(sf) {
    watch = hudIsInteractive
    key = $"ability_{name}"
    rendObj = ROBJ_BOX
    fillColor = 0x00000000
    borderWidth = hdpx(1)
    borderColor = (sf & S_HOVER) != 0 && hudIsInteractive.get() ? BtnBdHover : 0x00000000
    behavior = hudIsInteractive.get() ? Behaviors.Button : null
    onHover = @(on, elemPose) setTooltip(on ? tooltip : null, elemPose)
    valign = ALIGN_CENTER
    padding = hdpx(1)
    transform = {}
    animations = mkAbilityAnimations(name)
    children = content
  })
}

let mkScreamEncounterBlock = @(ability) function() {
  let { name = null } = ability
  if (name == null || name != SCREAM_ABILITY_NAME)
    return null
  let { curWatched, maxWatched } = abilitiesCharges[name]
  if (maxWatched.get() == null)
    return { watch = maxWatched}
  return {
    watch = [curWatched, maxWatched]
    children = mkText($"{curWatched.get()}/{maxWatched.get()}", {
      color = curWatched.get() == maxWatched.get() ? TextDisabled : TextNormal
    })
  }
}


let progressHeight = hdpxi(60)
let picProgress = Picture($"ui/skin#round_border.svg:{progressHeight}:{progressHeight}:P")
let abilityIconHeight = hdpxi(30)

let abilityIconPic = memoize(@(iconName) iconName == null ? null : {
  image = Picture($"!ui/{iconName}:{abilityIconHeight}:{abilityIconHeight}")
  rendObj = ROBJ_IMAGE
  size = [abilityIconHeight,abilityIconHeight]
})

let abText = memoize(@(name) name != null ? mkText(loc(loc($"{name}/name"))) : null)
let mkHint = memoize( @(actionHandleName) { children = controlHudHint({ id = actionHandleName text_params={padding=[hdpx(0), hdpx(4)]}}) rendObj = ROBJ_WORLD_BLUR_PANEL hplace = ALIGN_CENTER})

let mkAbility = function(abilityInfo, cooldown, nextUse) {

  let cdTimer = mkCountdownTimer(Watched(nextUse))
  let { name, actionHandleName = null } = abilityInfo
  let icoProgress = @() {
    watch = cdTimer
    rendObj = ROBJ_PROGRESS_CIRCULAR

    size = [abilityIconHeight*1.4, abilityIconHeight*1.4]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    fValue = cooldown.tofloat() > 0 ? (cdTimer.get().tofloat() / cooldown.tofloat()) : 0
    image = picProgress
    children = abilityIconPic(abilityInfo?.icon)
    fgColor = Color(150, 150, 150)
    bgColor = Color(0,0,0,0)
  }
  if (name not in hintWasShown)
    hintWasShown[name] <- false
  let showHint = Watched(!hintWasShown[name])
  let hideHint = function() {
    hintWasShown[name] <- true
    showHint.set(false)
  }
  let abNameHint = @() {
    size = [0,SIZE_TO_CONTENT]
    watch = showHint
    children = showHint.get() ? abText(name) : null halign = ALIGN_RIGHT onAttach = @() gui_scene.resetTimeout(20, hideHint)
  }
  let abilityComp = {
    
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    padding = hdpx(4)
    valign = ALIGN_CENTER
    halign = ALIGN_RIGHT
    rendObj = ROBJ_WORLD_BLUR_PANEL
    children = [
      abNameHint
      mkScreamEncounterBlock(abilityInfo)
      icoProgress
      mkHint(actionHandleName)
    ]
  }
  return mkAbilityCtor(abilityInfo, abilityComp, cooldown)
}

function calcStonesColor() {
  let numStones = gatherStonesAblityCurStones.get()
  if (numStones == 0) {
    return RedWarningColor
  }
  if (numStones == 1) {
    return OrangeHighlightColor
  }
  return TextNormal
}

function stonesGatherBlock() {
  if ((gatherStonesAblityCurStones.get()??-1) < 0)
    return { watch = gatherStonesAblityCurStones }
  let content = {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    padding = [hdpx(8), hdpx(4), hdpx(8), hdpx(12)]
    gap = hdpx(8)
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = [
      {
        rendObj = ROBJ_IMAGE
        margin = abilityIconHeight * 0.2
        size = [abilityIconHeight, abilityIconHeight]
        image = Picture($"ui/skin#ability/stones.svg:{abilityIconHeight}:{abilityIconHeight}:P")
      }
      mkText($"{gatherStonesAblityCurStones.get()}", { color = calcStonesColor(), size = [hdpx(18), SIZE_TO_CONTENT] }.__update(body_txt))
    ]
  }

  return {
    watch = gatherStonesAblityCurStones
    children = mkAbilityCtor({ name = "mothman_throw_stone" }, content)
  }
}

function monsterAbilities() {
  let watch = abilitiesInfo
  let needGatherStonesDisplay = (gatherStonesAblityCurStones.get() ?? -1) >= 0
  if (!abilitiesInfo.get()?.len() && !needGatherStonesDisplay)
    return { watch }

  let abilities = [stonesGatherBlock]
  foreach (abInfo in abilitiesInfo.get()) {
    let name = abInfo?.name
    let slot = mkAbility(abInfo, abilitiesCooldown.get()?[name] ?? 0, abilitiesNextUse.get()?[name] ?? 0)
    abilities.append(slot)
  }
  return {
    watch
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    halign = ALIGN_RIGHT
    children = abilities
  }
}

let monsterUi = {
  flow = FLOW_VERTICAL
  gap = hdpx(16)
  halign = ALIGN_RIGHT
  children = [
    monsterAbilities
    monsterDollBlock
  ]
}

return {
  monsterCompassBlock
  monsterUi
}

