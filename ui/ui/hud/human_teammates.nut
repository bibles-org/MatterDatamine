from "%ui/hud/state/teammates_es.nut" import teammatesGetWatched, groupmatesGetWatched

from "math" import ceil
from "%ui/components/text.nut" import dtext
from "das.inventory" import get_current_revive_price
from "%ui/helpers/remap_nick.nut" import remap_nick
from "%ui/fonts_style.nut" import sub_txt, tiny_txt
from "%ui/components/colors.nut" import TextHighlight, TeammateColor, TEAM0_TEXT_COLOR, GreenSuccessColor, RedFailColor
from "%ui/hud/state/cortical_vaults_es.nut" import corticalVaultsGetWatched
from "%ui/mainMenu/contacts/contactBlock.nut" import mkTeammateColorLine
from "%ui/hud/map/map_extraction_points.nut" import extractionIcon

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { heroAmValue } = require("%ui/hud/state/am_storage_state.nut")
let { orderedTeamNicks } = require("%ui/squad/squad_colors.nut")
let { corticalVaultsSet } = require("%ui/hud/state/cortical_vaults_es.nut")
let { teammatesSet, groupmatesSet } = require("%ui/hud/state/teammates_es.nut")
let { user_points } = require("%ui/hud/state/user_points.nut")
let { teammateRessurectDevices } = require("%ui/hud/state/resurrect_device_state.nut")

let DOWNED_COLOR = Color(240,100,50,255)
let pointerSize = [hdpxi(14), hdpxi(18)]

let squad_small_text = tiny_txt
let squad_medium_text = sub_txt

let weaponStyle = {
  color = Color(70, 70, 70, 30)
  fontFxColor = Color(0, 0, 0, 200)
  fontFxFactor = min(64, hdpx(64))
  fontFx = FFT_GLOW
  validateStaticText = true
}.__update(squad_small_text)

let downedIconAnimations = [{
  prop = AnimProp.opacity, from = 0.5, to = 1,
  duration = 0.5, play = true, loop = true, easing = CosineFull
}]

let downedIcon = {
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/skin#distress.svg:{hdpxi(18)}:{hdpxi(18)}:P")
  size = hdpxi(18)
  vplace = ALIGN_BOTTOM
  color = DOWNED_COLOR
  animations = downedIconAnimations
}

let skullIcon = {
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/skin#skull.svg:{hdpxi(18)}:{hdpxi(18)}:P")
  size = hdpxi(18)
  vplace = ALIGN_BOTTOM
  color = RedFailColor
}

function mkLoc(name){
  return loc("{0}/short".subst(name), loc(name))
}

function getPlayerNameColor(player, hero) {
  let isDowned = hero?.get().isDowned
  local textColor = isDowned ? DOWNED_COLOR : TEAM0_TEXT_COLOR
  let invalidPlayer = player.get().disconnected ||
    (player.get().possessed==ecs.INVALID_ENTITY_ID && player.get().scoring_player__firstSpawnTime < 0)
  if (invalidPlayer) {
    textColor = Color(100,100,100,100)
  } else if (player.get().scoring_player__isExtractedSuccess) {
    textColor = GreenSuccessColor
  } else if (player.get().player__isDead) {
    textColor = RedFailColor
  }
  return textColor
}

let weaponNameQuery = ecs.SqQuery("weaponNameQuery", { comps_ro=[["item__name", ecs.TYPE_STRING]] })
let getWeaponName = @(eid) weaponNameQuery.perform(eid, @(_, comp) comp)?.item__name ?? ""

let curWeaponStyle = weaponStyle.__merge({
  color = Color(120,120,120,30)
  ellipsis = true
  textOverflowX = TOVERFLOW_CHAR
  maxWidth = hdpx(120)
})
let mkCurWeapon = @(hero) function() {
  let eid = hero?.get().human_weap__currentGunEid ?? ecs.INVALID_ENTITY_ID
  let name = getWeaponName(eid)
  return {
    watch = hero
    children = dtext(mkLoc(name), curWeaponStyle)
    size = SIZE_TO_CONTENT
    clipChildren = true
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_RIGHT
  }
}

let mkMainWeapons = @(hero) function() {
  return{
    watch = hero
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    gap = hdpx(15)
    children = hero?.get().human_weap__gunEids
      .slice(0, 2)
      .map(function(weapEid){
        if (weapEid == ecs.INVALID_ENTITY_ID || weapEid == hero?.get().human_weap__currentGunEid)
          throw null
        let name = getWeaponName(weapEid)
        return dtext(mkLoc(name), weaponStyle)
    })
  }
}

let REVIVE_HINT_COLOR = Color(120,120,120,30)
let reviveAnim = [
  { prop = AnimProp.color, from=REVIVE_HINT_COLOR, to=REVIVE_HINT_COLOR, play=true, duration=15, trigger="wait", onFinish="blink" },
  { prop = AnimProp.color, from=REVIVE_HINT_COLOR, to=DOWNED_COLOR, easing=DoubleBlink, duration=0.7, trigger="blink", onFinish="wait" },
]

let reviveStyle = {
  color = Color(120,120,120,30)
  fontFxColor = Color(0, 0, 0, 90)
  fontFxFactor = min(64, hdpx(64))
  fontFx = FFT_GLOW
  animations = reviveAnim
}.__update(squad_medium_text)

let searchText = dtext(loc("hint/revive/find_neurodisk"), reviveStyle)
let collectAmText = @(am_count) dtext(loc("hint/revive/gather_am", {am_count}), reviveStyle)
let reviveText = dtext(loc("hint/revive"), reviveStyle)

let mkReviveTip = @(eid, corticalVault) function() {
  let price = get_current_revive_price(eid)
  let am_count = price - heroAmValue.get()
  let corticalExist = corticalVault?.get() != null
  let reviveTip = !corticalExist
                    ? null
                    : corticalVault?.get().item__containerOwnerEid != controlledHeroEid.get()
                      ? searchText
                      : am_count > 0
                        ? collectAmText(am_count)
                        : reviveText
  return {
    watch = [corticalVault, heroAmValue, controlledHeroEid]
    children = reviveTip
  }
}


let textHeight = calc_comp_size(dtext("A", squad_medium_text))[1]
let avatarHgt = textHeight*2

let mkPointerIcon = @(color) {
  rendObj = ROBJ_IMAGE
  size = pointerSize
  color
  image = Picture("!ui/skin#map_pin.svg:{0}:{1}:K".subst(pointerSize[0], pointerSize[1]))
}

function mkGroupmateInfo(eid) {
  let player = groupmatesGetWatched(eid)
  return function() {
    let hero = teammatesGetWatched(player.get().possessed)
    let corticalVaultEid = corticalVaultsSet.get().findindex(
      function(cvEid){
        let cv = corticalVaultsGetWatched(cvEid)
        return cv.get().playerItemOwner == eid
      }
    )
    let corticalVault = corticalVaultsGetWatched(corticalVaultEid)

    let name = dtext(weaponStyle.__merge({
      text = remap_nick(player.get().name)
      color = getPlayerNameColor(player, hero)
      watch = [player, hero]
    }, squad_medium_text))

    function pointer() {
      let watch = [user_points, player]
      let pointerToSet = user_points.get().findvalue(@(v) v?.name == player.get().name)
      if (pointerToSet == null)
        return {
          watch
          size = pointerSize
        }

      let colorIdx = orderedTeamNicks.get().findindex(@(v)v == player.get().name) ?? 0
      let color = TeammateColor[colorIdx]
      return {
        watch
        size = pointerSize
        children = mkPointerIcon(color)
      }
    }

    let firstRow = @() {
      watch = [hero, teammateRessurectDevices]
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      gap = hdpx(5)
      children = [
        pointer
        @() {
          watch = [hero, player]
          flow = FLOW_HORIZONTAL
          gap = hdpx(2)
          children = [
            mkTeammateColorLine(player.get().name)
            player.get().scoring_player__isExtractedSuccess ? extractionIcon : null
            hero?.get().isDowned && hero?.get().isAlive ? downedIcon : null
            player.get().player__isDead ? skullIcon : null
            name
          ]
        }
        teammateRessurectDevices.get()?[eid] == null ? null : {
          rendObj = ROBJ_IMAGE
          image = Picture("!ui/skin#microchip.svg:{0}:{0}:K".subst(hdpxi(17)))
          vplace = ALIGN_CENTER
          color = TextHighlight
          size = hdpxi(17)
        }
        { size = flex() }
        mkCurWeapon(hero)
      ]
    }

    return {
      watch = [player, hero, user_points]
      flow = FLOW_VERTICAL
      size = [flex(), avatarHgt]
      children = [
        firstRow
        hero?.get().isAlive ? mkMainWeapons(hero) : mkReviveTip(eid, corticalVault)
      ]
    }
  }
}

let groupmatesCompCtor = @(){
  watch = [groupmatesSet, corticalVaultsSet, teammatesSet]
  size = static [pw(40), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  hplace = ALIGN_LEFT
  vplace = ALIGN_CENTER
  gap = hdpx(1)
  padding = static [0,0,0,fsh(1)]
  children = groupmatesSet.get()
    .keys()
    .filter(@(eid) eid != controlledHeroEid.get())
    .sort(@(a, b) groupmatesGetWatched(a).get().name <=> groupmatesGetWatched(b).get().name)
    .map(mkGroupmateInfo)
}

return groupmatesCompCtor
