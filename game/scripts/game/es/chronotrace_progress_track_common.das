module chronotrace_progress_track_common shared
require ecs
require ecs.safe


def item_add_progress(var player__chronotracesProgression : Object;
                      itemTemplate : string;
                      progressName : string;
                      addition : int = 1)
  var costValue = 0
  var isRepeatedlyRewarded = false
  let templateInfo = getTemplateByName(itemTemplate)
  if templateInfo != null
    let costDataObj = get_ecs_object(getTemplateComponent(*templateInfo, "item__chronotracesProgressionInfo"))
    if costDataObj != null
      let onceListObj = get_ecs_object(*costDataObj, "once")
      if onceListObj != null
        costValue = (*onceListObj)[progressName] ?? 0
      if costValue == 0
        let repeatedlyListObj = get_ecs_object(*costDataObj, "repeatedly")
        if repeatedlyListObj != null
          costValue = (*repeatedlyListObj)[progressName] ?? 0
          isRepeatedlyRewarded = costValue != 0
  if costValue == 0
    return

  if !has(player__chronotracesProgression, itemTemplate)
    using() <| $(var obj : Object)
      player__chronotracesProgression |> set(itemTemplate, obj)
  var progression = getRW_ecs_object(player__chronotracesProgression[itemTemplate])
  if progression != null
    let curValue = (*progression)[progressName] ?? 0
    if curValue != 0 && !isRepeatedlyRewarded
      return
    let multiplier = isRepeatedlyRewarded ? addition : 1
    let newValue = curValue + multiplier * costValue
    set(*progression, progressName, newValue)
    print("[CHRONOTRACE_PROGRESS]: {itemTemplate} {progressName} {curValue} -> {newValue}")


def identify_victim(possessedByPlr : EntityId const?; anomaly_trap : Tag const?)
  var result = "militant"
  if anomaly_trap != null
    result = "trap"
  elif possessedByPlr == null || *possessedByPlr == INVALID_ENTITY_ID
    result = "monster"
  return result
