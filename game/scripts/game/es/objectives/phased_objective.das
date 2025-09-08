require ecs


[es(on_appear, tag=server, track=phased_objective__currentPhase)]
def update_phased_objective(evt : Event;
                            phased_objective__currentPhase : int;
                            phased_objective__phaseNames : StringList;
                            var objective__name : das_string&)
  if phased_objective__currentPhase < 0 || phased_objective__currentPhase >= length(phased_objective__phaseNames)
    return
  objective__name := phased_objective__phaseNames[phased_objective__currentPhase]
