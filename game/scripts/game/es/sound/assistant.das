require ecs
require app
require ecs.safe
require ecs.common
require soundEvent
require soundSystem
require math.random
require game.events.events_active_matter


def clear_state(var assistant__startSpeakAt : float&;
                var assistant__currentScriptStep : int&;
                var assistant__currentSoundEvent : SoundEvent&;
                var assistant__currentScriptName : das_string;
                var assistant__currentSoundName : das_string;
                var assistant__currentSoundLenght : float&)
  assistant__startSpeakAt = -1.0
  assistant__currentScriptStep = -1
  assistant__currentSoundEvent |> release()
  assistant__currentScriptName := ""
  assistant__currentSoundName := ""
  assistant__currentSoundLenght = 0.0


[es(tag=sound)]
def start_assistant_speak(evt : CmdStartAssistantSpeak;
                          assistant__startSpeakDelay : float;
                          var assistant__startSpeakAt : float&;
                          var assistant__currentScriptStep : int&;
                          var assistant__currentSoundEvent : SoundEvent&;
                          var assistant__currentScriptName : das_string;
                          var assistant__currentSoundName : das_string;
                          var assistant__currentSoundLenght : float&)
  clear_state(assistant__startSpeakAt,
              assistant__currentScriptStep,
              assistant__currentSoundEvent,
              assistant__currentScriptName,
              assistant__currentSoundName,
              assistant__currentSoundLenght)
  assistant__currentScriptStep = evt.skipBeepSound ? 0 : -1
  assistant__startSpeakAt = get_sync_time() + assistant__startSpeakDelay
  assistant__currentScriptName := evt.scriptName


[es(tag=sound)]
def stop_assistant_speak(evt : CmdStopAssistantSpeak;
                         var assistant__currentSoundEvent : SoundEvent&;
                         var assistant__startSpeakAt : float&;
                         var assistant__currentScriptStep : int&;
                         var assistant__currentSoundLenght : float&;
                         var assistant__currentSoundName : das_string;
                         var assistant__currentScriptName : das_string)
  clear_state(assistant__startSpeakAt,
              assistant__currentScriptStep,
              assistant__currentSoundEvent,
              assistant__currentScriptName,
              assistant__currentSoundName,
              assistant__currentSoundLenght)


[es(tag=sound, on_appear)]
def prepare_assistant_speak(evt : Event;
                            @shared_comp assistant__script : Object;
                            var assistant__scriptsRandomizerData : Object&)
  for scriptData in assistant__script
    if (scriptData.value as Object)?.selectOneFromArray ?? false
      using() <| $(var randomizerData : Object&)
        randomizerData |> set("lastSelectedIdx", 0)
        using() <| $(var idxs : IntList&)
          let scriptsArray = get_ecs_array(scriptData.value)
          if scriptsArray != null
            for i in iter_range(*scriptsArray)
              idxs |> push(i)
          idxs |> shuffle()
          randomizerData |> set("idxs", idxs)
        assistant__scriptsRandomizerData |> set(scriptData.key, randomizerData)


[es(tag=sound, no_order)]
def assistant_speak_update(evt : UpdateStageInfoAct;
                           assistant__speakGap : float;
                           assistant__startSpeakBeepSound : string;
                           @shared_comp assistant__script : Object;
                           var assistant__currentSoundLenght : float&;
                           var assistant__currentSoundName : das_string;
                           var assistant__currentScriptName : das_string;
                           var assistant__currentSoundEvent : SoundEvent&;
                           var assistant__startSpeakAt : float&;
                           var assistant__currentScriptStep : int&;
                           var assistant__scriptsRandomizerData : Object&)
  if assistant__startSpeakAt < 0.0 || assistant__startSpeakAt > evt.curTime
    return

  if assistant__currentScriptStep == -1 // time to play beep sound
    assistant__currentSoundEvent |> play(assistant__startSpeakBeepSound)
    let soundTime = get_length(assistant__startSpeakBeepSound)
    assistant__startSpeakAt = get_sync_time() + assistant__speakGap + float(soundTime) / 1000.0
  else
    let currentScriptName = string(assistant__currentScriptName)
    let scriptObj = assistant__script[currentScriptName]
    if scriptObj == null
      clear_state(assistant__startSpeakAt,
                  assistant__currentScriptStep,
                  assistant__currentSoundEvent,
                  assistant__currentScriptName,
                  assistant__currentSoundName,
                  assistant__currentSoundLenght)
      return
    let scriptObject = get_ecs_object(*scriptObj)
    if scriptObject == null
      clear_state(assistant__startSpeakAt,
                  assistant__currentScriptStep,
                  assistant__currentSoundEvent,
                  assistant__currentScriptName,
                  assistant__currentSoundName,
                  assistant__currentSoundLenght)
      return
    let scriptsArray = get_ecs_array((*scriptObject)["scripts"])
    let selectOneFromArray = (*scriptObject)["selectOneFromArray"] ?? false
    if scriptsArray == null || length(*scriptsArray) <= assistant__currentScriptStep
      clear_state(assistant__startSpeakAt,
                  assistant__currentScriptStep,
                  assistant__currentSoundEvent,
                  assistant__currentScriptName,
                  assistant__currentSoundName,
                  assistant__currentSoundLenght)
      return

    if selectOneFromArray
      var randomizerData = getRW_ecs_object(assistant__scriptsRandomizerData[currentScriptName])
      if randomizerData != null
        var idxs = randomizerData |> getRW_ecs_IntList("idxs")
        let lastSelectedIdx = randomizerData?.lastSelectedIdx ?? 0
        if idxs != null
          if length(*idxs) == 0 // generate new shuffle
            for i in iter_range(*scriptsArray)
              *idxs |> push(i)
            *idxs |> shuffle()
            if length(*idxs) > 1 && (*idxs)[length(*idxs) - 1] == lastSelectedIdx
              swap((*idxs)[length(*idxs) - 1], (*idxs)[length(*idxs) - 2])
          let lastIdx = length(*idxs) - 1
          assistant__currentScriptStep = (*idxs)[lastIdx]
          *idxs |> erase(lastIdx)
        *randomizerData |> set("lastSelectedIdx", assistant__currentScriptStep)
    let newSpeach = (*scriptsArray)[assistant__currentScriptStep] |> get_string("")
    if empty(newSpeach)
      clear_state(assistant__startSpeakAt,
                  assistant__currentScriptStep,
                  assistant__currentSoundEvent,
                  assistant__currentScriptName,
                  assistant__currentSoundName,
                  assistant__currentSoundLenght)
      return
    if selectOneFromArray
      assistant__currentScriptStep = length(*scriptsArray) // select one and stop playing next

    assistant__currentSoundLenght = float(get_length(newSpeach)) / 1000.0
    assistant__currentSoundName := newSpeach
    assistant__currentSoundEvent |> play(newSpeach)
    let soundTime = get_length(newSpeach)
    assistant__startSpeakAt = get_sync_time() + assistant__speakGap + float(soundTime) / 1000.0
  ++assistant__currentScriptStep
