from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { generate_level_evnironment_index } = require("das.level")
let { mkInfoTxt, mkText, mkMonospaceTimeComp } = require("%ui/components/commonComponents.nut")
let { BtnBdSelected, InfoTextValueColor } = require("%ui/components/colors.nut")

let nextEnvMinorColor = Color(70, 70, 70, 120)

let picSize = hdpx(50)
let picProgress = Picture("ui/skin#round_border.svg:{0}:{0}:K".subst(picSize))


let weatherPics = {
  strong_rain = Picture("!ui/skin#timeAndWeather/strong_rain.svg:{0}:{0}:K".subst(picSize))
  foggy = Picture("!ui/skin#timeAndWeather/foggy.svg:{0}:{0}:K".subst(picSize))
  overcast = Picture("!ui/skin#timeAndWeather/weak_rain.svg:{0}:{0}:K".subst(picSize))
  clouds = {
    night = Picture("!ui/skin#timeAndWeather/clear_night.svg:{0}:{0}:K".subst(picSize))
    day = Picture("!ui/skin#timeAndWeather/clear_day.svg:{0}:{0}:K".subst(picSize))
  }
  unknown = Picture("!ui/skin#timeAndWeather/weather_unknown.svg:{0}:{0}:K".subst(picSize))
}


let timePics = {
  Night = Picture("!ui/skin#timeAndWeather/night.svg:{0}:{0}:K".subst(picSize))
  Morning = Picture("!ui/skin#timeAndWeather/morning.svg:{0}:{0}:K".subst(picSize))
  Afternoon = Picture("!ui/skin#timeAndWeather/afternoon.svg:{0}:{0}:K".subst(picSize))
  Evening = Picture("!ui/skin#timeAndWeather/evening.svg:{0}:{0}:K".subst(picSize))
  Unknown = Picture("!ui/skin#timeAndWeather/time_unknown.svg:{0}:{0}:K".subst(picSize))
}

let sunVisibility = {
  Night = false
  Evening = false
  Morning = true
  Afternoon = true
}

function safe_div(a,b, def=0){
  if (b > 0)
    return a/b
  return def
}

function zoneTimeToDayTime(zoneTime) {
  
  if (zoneTime < 3.0)
    return "Night"
  
  else if (zoneTime < 9.0)
    return "Morning"
  
  else if (zoneTime < 15.5)
    return "Afternoon"
  
  else if (zoneTime < 21.0)
    return "Evening"
  
  else
    return "Night"

  return "Unknown"
}

function getZoneTimeOfDay(zone_info, zoneTime) {
  let timeVec = zone_info?.envInfo?.level__timeVec
  if (timeVec != null) {
    let timeIndex = generate_level_evnironment_index(
      zoneTime,
      zone_info?.envInfo?.level_synced_environment__timeOfDayChangeInterval ?? 1,
      timeVec.len(),
      zone_info?.envInfo?.level_synced_environment__timeOfDayChainSegments ?? 0,
      zone_info?.envInfo?.level_synced_environment__timeOfDaySeed ?? 0)
    if (timeIndex >= 0) {
      return zoneTimeToDayTime(timeVec[timeIndex])
    }
  }

  return "Unknown"
}

let mkIcon = @(icon, progress, customHdpx) {
  size = [ customHdpx(40), customHdpx(40) ]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    {
      size = [ pw(50), ph(50) ]
      rendObj = ROBJ_IMAGE
      image = icon
    }
    {
      size = flex()
      rendObj = ROBJ_PROGRESS_CIRCULAR
      image = picProgress
      fgColor = BtnBdSelected
      bgColor = nextEnvMinorColor
      fValue = 1.0 - progress
    }
  ]

}
let mkTextStyles = memoize(function(customHdpx) {
  let textStyle = {fontSize = customHdpx(14) }
  return {
    textStyle
    textInfoStyle = textStyle.__merge({color = InfoTextValueColor})
    openBr = mkText("(", textStyle)
    closeBr = mkText(")", textStyle)
  }
})

function mkZoneWidgets(matchingUTCTime) {

  function zoneTimeWidget(zone_info, customHdpx=hdpx) {
    let {textStyle, textInfoStyle, openBr, closeBr} = mkTextStyles(customHdpx)
    let changeInterval = zone_info?.envInfo?.level_synced_environment__timeOfDayChangeInterval ?? 1
    return function() {
      if (zone_info?.envInfo == null || matchingUTCTime.get() == 0) {
        return {
          watch = matchingUTCTime
        }
      }

      let currenTimeOfDay = getZoneTimeOfDay(zone_info, matchingUTCTime.get())
      let nextUpdateTime = ((matchingUTCTime.get() / changeInterval) + 1) * changeInterval
      let nextUpdateIn = nextUpdateTime - matchingUTCTime.get()
      let nextUpdateTimeOfDay = getZoneTimeOfDay(zone_info, nextUpdateTime)

      let currentDayTimeLoc = loc($"zoneInfo/time{currenTimeOfDay}")
      let nextDayTimeLoc = loc($"zoneInfo/time{nextUpdateTimeOfDay}")
      let timeLoc = $"{currentDayTimeLoc}"
      let nextTimeLoc = $"{nextDayTimeLoc}"

      let weatherLine = {
        flow = FLOW_HORIZONTAL
        gap = customHdpx(5)
        size = const [ flex(), SIZE_TO_CONTENT ]
        children = [
          mkText(timeLoc, textInfoStyle)
          { flow = FLOW_HORIZONTAL children = [
            openBr
            mkMonospaceTimeComp(nextUpdateIn, textStyle, const Color(180,180,180))
            closeBr
          ]}
        ]
      }

      return {
        watch = matchingUTCTime
        flow = FLOW_HORIZONTAL
        size = [ flex(), SIZE_TO_CONTENT ]
        gap = customHdpx(5)
        children = [
          mkIcon(timePics[currenTimeOfDay], safe_div(nextUpdateIn.tofloat(), changeInterval.tofloat()), customHdpx)
          {
            flow = FLOW_VERTICAL
            size = [ flex(), SIZE_TO_CONTENT ]
            children = [
              weatherLine
              mkInfoTxt(loc("zoneInfo/nextDayTime"), nextTimeLoc, textStyle).__update({gap = customHdpx(2)})
            ]
          }
        ]
      }
    }
  }


  function getZoneWeather(zone_info, unix_time) {
    let weatherChoice = zone_info?.envInfo?.level__weatherChoice
    if (weatherChoice != null) {
      let weatherIndex = generate_level_evnironment_index(
        unix_time,
        zone_info?.envInfo?.level_synced_environment__weatherChangeInterval ?? 1,
        weatherChoice.len(),
        zone_info?.envInfo?.level_synced_environment__weatherChainSegments ?? 0,
        zone_info?.envInfo?.level_synced_environment__weatherSeed ?? 0)
      if (weatherIndex >= 0) {
        let weatherTemplateName = $"{weatherChoice[weatherIndex]}"
        let weatherTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(weatherTemplateName)
        if (weatherTemplate != null)
          return {
            iconType = weatherTemplate?.getCompValNullable("skies_settings__iconType") ?? "unknown"
            locName = weatherTemplate?.getCompValNullable("skies_settings__locName") ?? "Unknown"
          }
      }
    }

    return { iconType = "unknown", locName = "Unknown" }
  }

  function zoneWeatherWidget(zoneInfo, customHdpx=hdpx) {
    let {textStyle, textInfoStyle, openBr, closeBr} = mkTextStyles(customHdpx)
    let changeInterval = zoneInfo?.envInfo?.level_synced_environment__weatherChangeInterval ?? 1
    return function() {
      if (matchingUTCTime.get() == 0 || zoneInfo?.envInfo == null) {
        return {
          watch = [matchingUTCTime]
        }
      }
      let currentWeather = getZoneWeather(zoneInfo, matchingUTCTime.get())
      let currenTimeOfDay = getZoneTimeOfDay(zoneInfo, matchingUTCTime.get())
      let current_SunVisible = sunVisibility?[currenTimeOfDay] ?? false
      let nextUpdateTime = ((matchingUTCTime.get() / changeInterval) + 1) * changeInterval
      let nextUpdateIn = nextUpdateTime - matchingUTCTime.get()
      let nextWeather = getZoneWeather(zoneInfo, nextUpdateTime)

      let weatherLine = {
        flow = FLOW_HORIZONTAL
        gap = customHdpx(5)
        size = [ flex(), SIZE_TO_CONTENT ]
        children = [
          mkText(loc(currentWeather.locName), textInfoStyle)
          {flow = FLOW_HORIZONTAL children = [openBr,
            mkMonospaceTimeComp(nextUpdateIn, textStyle, const Color(180,180,180)),
            closeBr]
          }
        ]
      }

      let iconTimeType = current_SunVisible ? "day" : "night"
      let weatherIcon = weatherPics[currentWeather.iconType]?[iconTimeType] ?? weatherPics[currentWeather.iconType]

      return {
        watch = matchingUTCTime
        flow = FLOW_HORIZONTAL
        size = [ flex(), SIZE_TO_CONTENT ]
        gap = customHdpx(5)
        children = [
          mkIcon(weatherIcon, safe_div(nextUpdateIn.tofloat(), changeInterval.tofloat()), customHdpx)
          {
            flow = FLOW_VERTICAL
            size = [ flex(), SIZE_TO_CONTENT ]
            children = [
              weatherLine
              mkInfoTxt(loc("zoneInfo/nextDayTime"), loc(nextWeather.locName), textStyle).__update({ gap = customHdpx(2) })
            ]
          }
        ]
      }
    }
  }
  return {zoneWeatherWidget, zoneTimeWidget}
}
return {
  mkZoneWidgets
}