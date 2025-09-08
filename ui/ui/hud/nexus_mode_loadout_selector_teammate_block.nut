from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "math" import  ceil

let { h2_txt, sub_txt } = require("%ui/fonts_style.nut")
let { BtnBdSelected, InfoTextValueColor, ItemIconBlocked, BtnBgDisabled, TextNormal, TextDisabled
} = require("%ui/components/colors.nut")
let { nexusSelectedNames } = require("%ui/hud/state/nexus_mode_state.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { teammatesSet, teammatesGetWatched } = require("%ui/hud/state/teammates_es.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let { TeammateColor } = require("%ui/hud/menus/components/teammateColor.nut")
let { localPlayerEid, localPlayerTeam } = require("%ui/hud/state/local_player.nut")
let { allNexusLoadouts } = require("%ui/hud/state/nexus_loadout_state.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")
let { mkFakeAttachments } = require("%ui/hud/menus/components/fakeItem.nut")
let { mapSize } = require("%ui/hud/minimap/map_state.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let faComp = require("%ui/components/faComp.nut")
let { TEAM_UNASSIGNED } = require("team")
let nexusTeammatesPlayerLoadoutInfo = Watched({})


let nexus_track_player_loadout_info = function(eid, comp) {
  if (comp.team != localPlayerTeam.get()) {
    return
  }
  let spawned = comp.possessed != ecs.INVALID_ENTITY_ID

  let chosenIndex = max(comp.nexus_player_loadout__chosenIndex, comp.nexus_player_loadout__takenIndex)
  let playerData = {
    spawned
    chosenIndex
    name = comp.name
    possessed = comp.possessed
    eid
  }
  nexusTeammatesPlayerLoadoutInfo.mutate(@(value) value[eid] <- playerData)
}

let nexus_players_loadout_info_query = ecs.SqQuery("nexus_players_loadout_info",
  {
    comps_ro = [
      ["team", ecs.TYPE_INT],
      ["possessed", ecs.TYPE_EID],
      ["nexus_player_loadout__chosenIndex", ecs.TYPE_INT],
      ["nexus_player_loadout__takenIndex", ecs.TYPE_INT],
      ["name", ecs.TYPE_STRING]
    ]
  }
)

localPlayerTeam.subscribe(function(v) {
  if (v != TEAM_UNASSIGNED)
    nexus_players_loadout_info_query.perform(nexus_track_player_loadout_info)
})

ecs.register_es("nexus_track_unspawned_players", {
  [["onInit", "onChange"]] = function(_evt, eid, comp) {
    nexus_track_player_loadout_info(eid, comp)
  }

  onDestroy = function(eid, _comp) {
    if (eid in nexusTeammatesPlayerLoadoutInfo.get())
      nexusTeammatesPlayerLoadoutInfo.mutate(@(value) value.$rawdelete(eid))
  }
}, {
  comps_track = [
    ["team", ecs.TYPE_INT],
    ["possessed", ecs.TYPE_EID],
    ["nexus_player_loadout__chosenIndex", ecs.TYPE_INT],
    ["nexus_player_loadout__takenIndex", ecs.TYPE_INT]
  ],
  comps_ro = [["name", ecs.TYPE_STRING]]
}, {tags = "gameClient"})


let statusIconSize = hdpx(20)
let chooseMilitantStatusIcon = function(isAlive, isDowned) {
  return isDowned && isAlive
    ? const faComp("distress.svg", { color = Color(120,120,120), size = statusIconSize})
    : isAlive
      ? const faComp("heartbeat.svg", {color = Color(90, 230, 240), size = statusIconSize})
      : const faComp("skull.svg", {color = Color(20,20,20,140), size = statusIconSize})
}

let mkNotSpawnedIcon = chooseMilitantStatusIcon(false, false)
let weaponIconSize = [hdpxi(70), hdpxi(35)]

function mkTeammateIcon(teammateWatched) {
  if (teammateWatched == null)
    return null
  return function() {
    let {isAlive=false, isDowned=false, possessedByPlr=null} = teammateWatched.get()
    return {
      watch = teammateWatched
      halign = ALIGN_CENTER
      padding =[0, hdpx(2)]
      children = possessedByPlr == ecs.INVALID_ENTITY_ID
        ? mkNotSpawnedIcon
        : chooseMilitantStatusIcon(isAlive, isDowned)
      }
  }
}

let isSelected = @(name) name in nexusSelectedNames.get()

let mkSelectedLine = @(name) @() {
  rendObj = ROBJ_SOLID
  size = const [hdpx(4), flex()]
  margin = const [hdpx(2), hdpx(1)]
  watch = nexusSelectedNames
  color = isSelected(name) ? BtnBdSelected : BtnBgDisabled
}

function mkSelectedWeaponComp(templateName, attachments, group){
  let image = itemIconNoBorder(templateName,
    const {
      width = weaponIconSize[0]
      height = weaponIconSize[1]
      silhouette = ItemIconBlocked
      shading = "full"
      vplace = ALIGN_CENTER
      margin = [hdpx(4), 0, hdpx(4), 0]
    }, mkFakeAttachments(attachments))
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let itemName = template?.getCompValNullable("item__name")
  return {
    size = const [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = const hdpx(8)
    valign = ALIGN_CENTER
    clipChildren = true
    children = [
      image
      mkText(loc(itemName), {
        size = const [flex(), SIZE_TO_CONTENT]
        scrollOnHover = true
        group
        behavior = Behaviors.Marquee
      }.__update(sub_txt) )
    ]
  }
}

function mkSelectedWeapon(loadoutData, group) {
  let { items = [] } = loadoutData
  let weapon = items.findvalue(@(v) v?.slotName == "weapon_0")
  if (weapon == null)
    return null
  let { itemId, templateName } = weapon
  let attachments = items
    .filter(@(v) v?.parentItemId == itemId)
    .map(@(v) v?.templateName)
  return mkSelectedWeaponComp(templateName, attachments, group)
}

let getSelWeaponPlaceHolder = @() const {size = calc_comp_size(mkSelectedWeaponComp("hk_mp5n_gun", [], null))}

function mkTeammateBlock(data) {
  let { name, possessed, eid, chosenIndex = null} = data
  function onClick() {
    if (name not in nexusSelectedNames.get())
      nexusSelectedNames.mutate(@(v) v[name] <- true)
    else
      nexusSelectedNames.mutate(@(v) v.$rawdelete(name))
  }
  function onHover(on) {
    if (on && eid != localPlayerEid.get())
      setTooltip(isSelected(name) ? loc("nexus/selectPlayer") : loc("nexus/deselectPlayer"))
    else
      setTooltip(null)
  }
  let selLine = mkSelectedLine(name)
  let teammateWatched = teammatesGetWatched(possessed)
  let group = ElemGroup()
  return @() {
    watch = const [hudIsInteractive, localPlayerEid]
    size = const [hdpx(320), SIZE_TO_CONTENT]
    behavior = hudIsInteractive.get() && eid != localPlayerEid.get() ? Behaviors.Button : null
    onHover
    group
    onClick
    padding = const [0, hdpx(4)]
    flow = FLOW_HORIZONTAL
    rendObj = ROBJ_WORLD_BLUR_PANEL
    children = [
      selLine,
      @() {
        size = const [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = const hdpx(4)
        valign = ALIGN_CENTER
        children = [
          mkTeammateIcon(teammateWatched),
          @() {
            size = const [flex(2), SIZE_TO_CONTENT]
            flow = FLOW_HORIZONTAL
            watch = [teammateWatched, localPlayerEid]
            gap = const hdpx(6)
            valign = ALIGN_CENTER
            padding = const hdpx(4)
            clipChildren = true
            children = mkText(remap_nick(name), {
                size = const [flex(), SIZE_TO_CONTENT]
                behavior = Behaviors.Marquee
                color = localPlayerEid.get() == possessed
                  ? InfoTextValueColor
                  : (teammateWatched?.get().isAlive ?? true) ? TextNormal : TextDisabled
              }.__update(sub_txt))
          },
          @() {
            size = const [flex(3), SIZE_TO_CONTENT]
            watch = [allNexusLoadouts, teammateWatched]
            children  = !(teammateWatched?.get().isAlive ?? true) || allNexusLoadouts.get()?[eid][chosenIndex] == null
              ? getSelWeaponPlaceHolder()
              : mkSelectedWeapon(allNexusLoadouts.get()[eid][chosenIndex], group)
          }
        ]
      }
    ]
  }
}

let teammatesContent = @() {
  watch = [teammatesSet, nexusTeammatesPlayerLoadoutInfo]
  flow = FLOW_VERTICAL
  gap = const hdpx(4)
  halign = ALIGN_CENTER
  children = nexusTeammatesPlayerLoadoutInfo.get().values()
    .sort(@(a, b)   teammatesGetWatched(b?.possessed)?.get().isAlive <=> teammatesGetWatched(a?.possessed)?.get().isAlive || a.name <=> b.name)
    .map(@(data) mkTeammateBlock(data))
}

let teammatesHeader = const {
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
  valign = ALIGN_CENTER
  size = [flex(), SIZE_TO_CONTENT]
  children = [
    mkText(loc("My Team"), h2_txt)
    {size = flex()}
    TeammateColor
  ]
}

return function() {
  let mapGap = hdpxi(mapSize[0] * 0.025)
  let blockHeight = mapSize[1] + mapGap * 3 + hdpx(32)
  return {
    minHeight = const blockHeight
    flow = FLOW_VERTICAL
    gap = const hdpx(8)
    vplace = ALIGN_CENTER
    children = [
      teammatesHeader
      teammatesContent
    ]
  }
}
