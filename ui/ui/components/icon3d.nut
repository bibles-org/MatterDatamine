from "%ui/ui_library.nut" import *

#allow-auto-freeze

let RENDER_PARAMS = @"{atlasName}render{
  itemName:t={itemName};animchar:t={animchar};autocrop:b=false;
  yaw:r={yaw};pitch:r={pitch};roll:r={roll};
  w:i={width};h:i={height};offset:p2={offset_x},{offset_y};scale:r={scale};
  outline:c={outlineColor};shading:t={shading};silhouette:c={silhouetteColor};
  silhouetteHasShadow:b={silhouetteHasShadow}
  silhouetteMinShadow:r={silhouetteMinShadow}
  animation:t={animation}; enviPanoramaTex:t={enviPanoramaTex}; enviExposure:r={enviExposure}; sun:c={sunColor}
  {animationParams}
  recalcAnimation:b={recalcAnimation}
  {zenith}{azimuth}
  {attachments}
  {hideNodes}
  {objTexReplaceRules}
  {objTexSetRules}
  {shaderColors}
  {lights}
  {antiAliasing}
}.render"

let iconWidgetDef = {
  width = hdpx(64)
  height = hdpx(64)
  outline = [0,0,0,0]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  shading = "full" 
  silhouette = [192,192,192,255]
  silhouetteHasShadow = false
  silhouetteMinShadow = 1.0
}
#forbid-auto-freeze
let cachedPictures = {}
#allow-auto-freeze
function getPicture(source) {
  local pic = cachedPictures?[source]
  if (pic)
    return pic
  pic = Picture(source)
  cachedPictures[source] <- pic
  return pic
}

function getTexReplaceString(item) {
  #forbid-auto-freeze
  let { objTexReplace = null } = item
  if (objTexReplace == null)
    return ""

  if (type(objTexReplace) == "string")
    return objTexReplace

  let ruleSets = type(objTexReplace) == "array" ? objTexReplace : [objTexReplace]
  let list = []
  foreach (idx, set in ruleSets) {
    list.append($"r{idx}")
    list.append("{")
    foreach (from, to in set)
      list.append($"objTexReplace:t={from};objTexReplace:t={to};")
    list.append("}")
  }
  return "".join(list)
}

function getTexSetString(item) {
  let { objTexSet = null } = item
  if (objTexSet == null)
    return ""

  let ruleSets = type(objTexSet) == "array" ? objTexSet : [objTexSet]
  let list = []
  foreach (idx, set in ruleSets) {
    list.append($"r{idx}")
    list.append("{")
    foreach (key, pair in set) {
      let from = pair?.keys()[0]
      let to = pair?[from]
      if (from != null && to != null) {
        list.append($"objTexSet:t={key};objTexSet:t={from};objTexSet:t={to};")
      }
    }
    list.append("}")
  }
  return "".join(list)
}

let getTMatrixString = @(m)
  "[{0}]".subst(" ".join(array(4).map(@(_, i) $"[{m[i].x}, {m[i].y}, {m[i].z}]")))

function getShaderColorsString(item) {
  #forbid-auto-freeze
  let { shaderColors = null } = item
  if (shaderColors == null || type(shaderColors) != "table")
    return ""
  let list = []
  list.append("shaderColors{")
  foreach (name, value in shaderColors){
    if (type(value) == "array" && value.len() > 3)
      list.append($"{name}:p4={value[0]},{value[1]},{value[2]},{value[3]};")
  }
  list.append("}")
  return "".join(list)
}

function getLightsString(lights) {
  if (lights.len() == 0)
    return ""
  #forbid-auto-freeze
  let list = []
  list.append("lights {")

  foreach (idx, light in lights) {
    let color = light?.color ? $"color:c={light.color};" : ""
    let brightness = light?.brightness ? $"brightness:r={light.brightness};" : ""
    let zenith = light?.zenith ? $"zenith:r={light.zenith};" : ""
    let azimuth = light?.azimuth ? $"azimuth:r={light.azimuth};" : ""

    let lightBlock = $"light{idx+1} \{{color} {brightness} {zenith} {azimuth}\}"
    list.append(lightBlock)
  }

  list.append("}")

  return "\n  ".join(list)
}

function iconWidget(item, params = iconWidgetDef) {
  let { children = null } = params
  let { iconName = "", itemName = "" } = item
  if (iconName == "") {
    return {
      children
    }
  }

  let outlineColor = ",".join(params?.outline ?? iconWidgetDef.outline)
  let outlineColorInactive = ",".join(params?.outlineInactive ?? iconWidgetDef.outline)
  let {
    width = iconWidgetDef.width,
    height = iconWidgetDef.height,
    vplace = iconWidgetDef.vplace,
    hplace = iconWidgetDef.hplace,
    shading = iconWidgetDef.shading
  } = params
  let silhouetteColor = ",".join(params?.silhouette ?? iconWidgetDef.silhouette)
  let silhouetteColorInactive = ",".join(params?.silhouetteInactive ?? iconWidgetDef.silhouette)
  let silhouetteHasShadow = params?.silhouetteHasShadow ?? iconWidgetDef.silhouetteHasShadow
  let silhouetteMinShadow = params?.silhouetteMinShadow ?? iconWidgetDef.silhouetteMinShadow
  let imageHeight = height.tointeger()
  let imageWidth = width.tointeger()
  let zenith = item?.lightZenith != null ? $"zenith:r={item.lightZenith};" : ""
  let azimuth = item?.lightAzimuth != null  ? $"azimuth:r={item.lightAzimuth};" : ""
  let objTexReplace = getTexReplaceString(item)
  let objTexSet = getTexSetString(item)
  let shaderColors = getShaderColorsString(item)
  let enviPanoramaTex = item?.enviPanoramaTex ?? params?.enviPanoramaTex ?? "icon_render_panorama_tex_d"
  let enviExposure = item?.enviExposure ?? params?.enviExposure ?? 64.0
  let lights = getLightsString(item?.lights ?? params?.lights ?? [])
  let antiAliasing = item?.antiAliasing ?? 4
  #forbid-auto-freeze
  let attachments = []
  local haveActiveAttachments = false
  foreach (i, attachment in item?.iconAttachments ?? []) {
    let active = attachment?.active ?? false
    if (shading == "full" && !active) {
      
      continue
    }
    haveActiveAttachments = haveActiveAttachments || active
    let attOutlineColor = active ? outlineColor : outlineColorInactive
    let attSilhouetteColor = active ? silhouetteColor : silhouetteColorInactive
    let attachType = attachment?.attachType != null ? $"attachType:t={attachment.attachType};" : ""
    local hideNodes = (attachment?.hideNodes ?? []).map(@(node) $"node:t={node};")
    hideNodes = hideNodes.len() > 0 ? "hideNodes{{0}}".subst("".join(hideNodes)) : ""
    attachments.append($"a{i}")
    attachments.append("{")
    attachments.append($"animchar:t={attachment?.animchar};slot:t={attachment?.slot};scale:r={attachment?.scale ?? 1.0};{attachType}{hideNodes}")
    attachments.append($"outline:c={attOutlineColor};shading:t={attachment?.shading ?? "same"};silhouette:c={attSilhouetteColor};objTexReplaceRules\{{getTexReplaceString(attachment)}\}{getShaderColorsString(attachment)}")
    attachments.append("}")
  }
  foreach (decorator in item?.decorators ?? []) {
    attachments.append("a{")
    attachments.append($"relativeTm:m={getTMatrixString(decorator?.relativeTm)};")
    attachments.append($"animchar:t={decorator?.animchar};parentNode:t={decorator?.nodeName};")
    attachments.append("shading:t=same;attachType:t=node;")
    attachments.append($"swapYZ:b={decorator?.swapYZ ?? true};")
    attachments.append("}")
  }

  let hideNodes = (item?.hideNodes ?? []).map(@(node) $"node:t={node};")

  let joinedAnimParams = ";".join(item?.animationParams.map(@(v,k) $"{k}:r={v}").values() ?? [])
  let animationParams = joinedAnimParams ? $"animationParams\{{joinedAnimParams}\}" : ""

  let imageSource = RENDER_PARAMS.subst({
    atlasName = item?.atlasName ?? "ui/skin#"
    itemName
    animchar = iconName
    animation = item?.animation ?? ""
    recalcAnimation = item?.iconRecalcAnimation ?? false
    yaw = item?.iconYaw ?? 0
    pitch = item?.iconPitch ?? 0
    roll = item?.iconRoll ?? 0
    width = imageWidth
    height = imageHeight
    offset_x = item?.iconOffsX ?? 0
    offset_y = item?.iconOffsY ?? 0
    scale = item?.iconScale ?? 1
    outlineColor
    silhouetteColor = haveActiveAttachments ? silhouetteColorInactive : silhouetteColor
    silhouetteHasShadow
    silhouetteMinShadow
    sunColor = item?.sunColor ?? "255,255,255,255"
    shading
    zenith
    azimuth
    objTexReplaceRules = "objTexReplaceRules{{0}}".subst(objTexReplace)
    objTexSetRules = "objTexSetRules{{0}}".subst(objTexSet)
    attachments = attachments.len() > 0 ? "attachments{{0}}".subst("".join(attachments)) : ""
    hideNodes = hideNodes.len() > 0 ? "hideNodes{{0}}".subst("".join(hideNodes)) : ""
    shaderColors,
    animationParams,
    enviPanoramaTex,
    enviExposure,
    lights,
    antiAliasing = "ssaaX:i={0};ssaaY:i={0};".subst(antiAliasing)
  })

  let image = getPicture(imageSource)

  return {
    rendObj = ROBJ_IMAGE
    image
    key = image
    vplace
    hplace
    children
    size = [width,height]
    keepAspect = true
    picSaturate = item?.picSaturate ?? 1.0

    animations = static [{ prop=AnimProp.opacity, from=0, to=1, duration=0.7, play=true, easing=OutCubic }]
  }.__update(params)
}

return iconWidget
