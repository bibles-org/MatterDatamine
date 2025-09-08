require ecs
require ecs.safe
require DagorSystem
require NetPropsRegistry

// on_create__spawnActivatedShellBlk creates a shell entity which wants to explode the moment
// it is created. If it is the first time such shell is created there is a chance that its
// explosion event `CmdShellExplodeClient` will be recieved by clients before net props registration
// event. In such cases we will get a logerr `getProps|shell: unsigned(16) >= 16` as the client
// does not yet have those props.
// This system tries to avoid this be initing props entity with on_create__spawnActivatedShellBlk
// will beforehand.
[es(tag=server, on_appear)]
def preload_spawn_activated_shell_props_es(evt : Event;
                                           eid : EntityId;
                                           preloadSpawnActivatedShellProps : StringList)
  for templateName in preloadSpawnActivatedShellProps
    let templ = getTemplateByName(string(templateName))
    if templ == null
      logerr("Entity ({eid})<{getEntityTemplateName(eid)}> tried to preload props for template '{templateName}' but it does not exist.")
      continue
    let blk = getTemplateComponent(*templ, "on_create__spawnActivatedShellBlk") ?? ""
    register_net_props(blk, "shell")
    register_net_props(blk, "damage")
    register_net_props(blk, "ballistics")
