require ecs
require ecs.safe
require PhysVars
require DngNet
require game.events.events_active_matter


[es(on_appear, tag=render, before=anim_phys_init_es)]
def hair_hider_init_es(evt : Event; char_flags__hasHeadwearOn : bool; var char_flags__headwearVarId : int&; var phys_vars : PhysVars)
  char_flags__headwearVarId = registerVar(phys_vars, "wears_hat", char_flags__hasHeadwearOn ? 1.0 : 0.0)


[es(tag=render, track=char_flags__hasHeadwearOn)]
def hair_hider_es(evt : Event; char_flags__hasHeadwearOn : bool; char_flags__headwearVarId : int; var phys_vars : PhysVars)
  setVar(phys_vars, char_flags__headwearVarId, char_flags__hasHeadwearOn ? 1.0 : 0.0)


[es(tag=server, on_appear, track=(char_flags__hasSuitOn, char_flags__hasHeadwearOn))]
def hood_toogle(evt : Event;
                char_flags__hasSuitOn : bool;
                char_flags__hasHeadwearOn : bool;
                human_equipment__slots : Object)
  if char_flags__hasSuitOn
    let suitEid = human_equipment__slots["suit"] ?? INVALID_ENTITY_ID
    query(suitEid) <| $ [es] (animchar__hoodDownNodeName, animchar__hoodUpNodeName : string)
      if char_flags__hasHeadwearOn
        send_net_event(suitEid, EventAnimcharShowGeomtreeNode(nodeName = animchar__hoodDownNodeName))
        send_net_event(suitEid, EventAnimcharHideGeomtreeNode(nodeName = animchar__hoodUpNodeName))
      else
        send_net_event(suitEid, EventAnimcharShowGeomtreeNode(nodeName = animchar__hoodUpNodeName))
        send_net_event(suitEid, EventAnimcharHideGeomtreeNode(nodeName = animchar__hoodDownNodeName))
