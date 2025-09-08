import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { ceil } = require("math")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { dtext } = require("%ui/components/text.nut")
let { get_current_revive_price } = require("das.inventory")
let { heroAmValue } = require("%ui/hud/state/am_storage_state.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let { sub_txt, tiny_txt } = require("%ui/fonts_style.nut")
let { TextHighlight, TeammateColor, TEAM0_TEXT_COLOR } = require("%ui/components/colors.nut")
let { orderedTeamNicks } = require("%ui/squad/squad_colors.nut")
let { corticalVaultsSet, corticalVaultsGetWatched } = require("%ui/hud/state/cortical_vaults_es.nut")
let { teammatesSet,
      teammatesGetWatched,
      groupmatesSet,
      groupmatesGetWatched
    } = require("%ui/hud/state/teammates_es.nut")
let { user_points } = require("%ui/hud/state/user_points.nut")
let { mkTeammateColorLine } = require("%ui/mainMenu/contacts/contactBlock.nut")
let { teammateRessurectDevices } = require("%ui/hud/state/resurrect_device_state.nut")

let DEAD_TEXT_COLOR = Color(80,30,30,120)
let DOWNED_COLOR = Color(240,100,50,255)
let pointerSize = [hdpxi(14), hdpxi(18)]

let squad_small_text = tiny_txt
let squad_medium_text = sub_txt

let weaponStyle = {
  color = Color(70, 70, 70, 30)
  fontFxColor = Color(0, 0, 0, 90)
  fontFxFactor = min(64, hdpx(64))
  fontFx = FFT_GLOW
  validateStaticText = true
}.__update(squad_small_text)

let unitDownedSz = [fsh(1.5), fsh(1.5)]
let unitDowned = Picture("!ui/skin#distress.svg:{0}:{1}:K".subst(
  ceil(unitDownedSz[0]), ceil(unitDownedSz[1])))

let downedIconAnimations = [{
  prop = AnimProp.opacity, from = 0.5, to = 1,
  duration = 0.5, play = true, loop = true, easing = CosineFull
}]

let downedIcon = {
  rendObj = ROBJ_IMAGE
  color = DOWNED_COLOR
  image = unitDowned
  size = unitDownedSz
  vplace = ALIGN_BOTTOM
  animations = downedIconAnimations
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
  } else if (!hero?.get().isAlive) {
    textColor = DEAD_TEXT_COLOR
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
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = hdpx(5)
      children = [
        hero?.get().isDowned ? downedIcon : null
        pointer
        @() {
          watch = player
          flow = FLOW_HORIZONTAL
          gap = hdpx(2)
          children = [
            mkTeammateColorLine(player.get().name)
            name
          ]
        }
        teammateRessurectDevices.get()?[eid] == null ? null : {
          rendObj = ROBJ_IMAGE
          image = Picture("!ui/skin#microchip.svg:{0}:{0}:K".subst(hdpxi(17)))
          vplace = ALIGN_CENTER
          color = TextHighlight
          size = [hdpxi(17), hdpxi(17)]
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
  size = [pw(40), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  hplace = ALIGN_LEFT
  vplace = ALIGN_CENTER
  gap = hdpx(1)
  padding = [0,0,0,fsh(1)]
  children = groupmatesSet.get()
    .keys()
    .filter(@(eid) eid != controlledHeroEid.get())
    .sort(@(a, b) groupmatesGetWatched(a).get().name <=> groupmatesGetWatched(b).get().name)
    .map(mkGroupmateInfo)
}

return groupmatesCompCtor
