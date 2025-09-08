import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let mkIcon3d = require("%ui/components/icon3d.nut")

let defaultIcon = "!ui/skin#info/info_icon.svg"


let getNodesForHide = @(template)
  template?.getCompValNullable("disableDMParts")?.getAll() ?? []
function getIconInfoByGameTemplate(template, params = {}, iconAttachments = []){
  let reassign = @(value, key) key in params ? params[key] : value
  return {
    iconName = template.getCompValNullable("item__animcharInInventoryName") ?? template.getCompValNullable("animchar__res")
    iconBypassName = template.getCompValNullable("animchar__icon")
    objTexReplace = template.getCompValNullable("animchar__objTexReplace")?.getAll()
    iconPitch = reassign(template.getCompValNullable("item__iconPitch"), "itemPitch")
    iconYaw = reassign(template.getCompValNullable("item__iconYaw"), "itemYaw")
    iconRoll = reassign(template.getCompValNullable("item__iconRoll"), "itemRoll")
    iconOffsX = reassign(template.getCompValNullable("item__iconOffset")?.x, "itemOfsX")
    iconOffsY = reassign(template.getCompValNullable("item__iconOffset")?.y, "itemOfsY")
    iconScale = reassign(template.getCompValNullable("item__iconScale"), "itemScale")
    lightZenith = reassign(template.getCompValNullable("item__iconZenith"), "iconZenith")
    lightAzimuth = reassign(template.getCompValNullable("item__iconAzimuth"), "iconAzimuth")
    iconRecalcAnimation = reassign(template.getCompValNullable("item__iconRecalcAnimation"), "iconRecalcAnimation")
    hideNodes = getNodesForHide(template)
    iconAttachments
  }
}

function iconByGameTemplate(gametemplate, params = {}, iconAttachments = []){
  if (gametemplate != null) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(gametemplate)
    if (template != null) {
      let itemInfo = getIconInfoByGameTemplate(template, params, iconAttachments)
      return itemInfo.iconName != null ?
          mkIcon3d(itemInfo, params)
        : {
          rendObj = ROBJ_IMAGE
          size = [params?.width, params?.height]
          image = Picture($"{itemInfo?.iconBypassName ?? defaultIcon}:{params?.width}:{params?.height}:P")
          key = itemInfo.iconBypassName
          keepAspect = true
          animations = [{ prop=AnimProp.opacity, from=0, to=1, duration=0.7, play=true, easing=OutCubic }]
        }.__update(params)
    }
  }
  return {
    size = [params?.width, params?.height]
  }
}

function itemIcon(template, params = {}, iconAttachments = [], portraitParams = {}) {
  return {
    rendObj = ROBJ_BOX
    borderColor = Color(160, 160, 160, 10)
    fillColor = Color(0, 0, 0, 120)
    borderWidth = 2
    margin = hdpx(5)
    padding = hdpx(5)

    children = [iconByGameTemplate(template, params, iconAttachments)]
  }.__update(portraitParams)
}

function itemIconNoBorder(template, params = {}, iconAttachments = [], portraitParams = {}) {
  return iconByGameTemplate(template, params, iconAttachments).__update(portraitParams)
}

return {
  itemIcon
  itemIconNoBorder
}
