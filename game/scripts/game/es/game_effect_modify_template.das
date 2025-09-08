require ecs
require app
require strings
require DngNet
require game.events.events
require game.es.game_effect_common

[es(tag=gameClient, on_appear)]
def game_effect_update_template_client_es(evt : Event;
                                          game_effect__clientSubtractTemplate : string = "";
                                          game_effect__clientAddTemplate : string = "";
                                          game_effect__attachedTo : EntityId)
  if game_effect__clientSubtractTemplate != ""
    removeSubTemplate(game_effect__attachedTo, game_effect__clientSubtractTemplate)
  if game_effect__clientAddTemplate != ""
    addSubTemplate(game_effect__attachedTo, game_effect__clientAddTemplate)


[es(tag=gameClient, on_appear)]
def game_effect_replace_template_client_es(evt : Event;
                                           game_effect__clientReplaceTemplateFrom : string;
                                           game_effect__clientReplaceTemplateTo : string = "";
                                           game_effect__attachedTo : EntityId)
  let originalTemplName = getEntityFutureTemplateName(game_effect__attachedTo)
  if find(originalTemplName, game_effect__clientReplaceTemplateFrom) == -1
    return
  removeSubTemplate(game_effect__attachedTo, game_effect__clientReplaceTemplateFrom)
  if game_effect__clientReplaceTemplateTo != ""
    addSubTemplate(game_effect__attachedTo, game_effect__clientReplaceTemplateTo)


[es(tag=server, on_appear)]
def game_effect_update_template_server_es(evt : Event;
                                          game_effect__subtractTemplate : string = "";
                                          game_effect__addTemplate : string = "";
                                          game_effect__attachedTo : EntityId)
  if game_effect__subtractTemplate != ""
    removeSubTemplate(game_effect__attachedTo, game_effect__subtractTemplate)
  if game_effect__addTemplate != ""
    addSubTemplate(game_effect__attachedTo, game_effect__addTemplate)


[es(on_appear)]
def game_effect_attached_template_appear(evt : Event;
                                         game_effect__attachedTemplate : string;
                                         game_effect__attachedTo : EntityId)
  addSubTemplate(game_effect__attachedTo, game_effect__attachedTemplate)


[es(on_disappear)]
def game_effect_attached_template_disappear(evt : Event;
                                            game_effect__attachedTemplate : string;
                                            game_effect__attachedTo : EntityId)
  removeSubTemplate(game_effect__attachedTo, game_effect__attachedTemplate)


[es(on_appear)]
def game_effect_temporarily_remove_template_appear(evt : Event;
                                                   game_effect__temporarilyRemoveTemplate : string;
                                                   game_effect__attachedTo : EntityId)
  removeSubTemplate(game_effect__attachedTo, game_effect__temporarilyRemoveTemplate)


[es(on_disappear)]
def game_effect_temporarily_remove_template_disappear(evt : Event;
                                                      game_effect__temporarilyRemoveTemplate : string;
                                                      game_effect__attachedTo : EntityId)
  addSubTemplate(game_effect__attachedTo, game_effect__temporarilyRemoveTemplate)
