require ecs
require PhysVars

[es(on_appear, tag=render, before=anim_phys_init_es)]
def human_anim_fpv_init(evt : Event; var human_anim__isFpvVarId : int&; var phys_vars : PhysVars)
  human_anim__isFpvVarId = registerVar(phys_vars, "is_fpv", 0.0)


[es(before=human_anim_es, tag=render)]
def human_anim_fpv(info : UpdateStageInfoAct; isHeroCockpitCam : bool; camera__active : bool)
  if !camera__active
    return
  query() <| $ [es] (human_anim__isFpvVarId : int;
                     var phys_vars : PhysVars;
                     cockpitEntity : Tag const?)
    let isFpv = isHeroCockpitCam && cockpitEntity != null
    setVar(phys_vars, human_anim__isFpvVarId, isFpv ? 1. : 0.)
