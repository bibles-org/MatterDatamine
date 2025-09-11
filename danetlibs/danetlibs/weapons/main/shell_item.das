require ecs
require DagorSystem
require DaWeaponProps
require NetPropsRegistry

[es(on_appear, before=gun_zeroing_es)]
def shell_item_es(evt : Event;
                  item__shell : string;
                  var shell_props : ShellPropIds&)
  if int(shell_props.shellId) < 0
    shell_props.shellId = int16(register_net_props(item__shell, "shell"))
    shell_props.damageId = int16(register_net_props(item__shell, "damage"))
    shell_props.ballisticsId = int16(register_net_props(item__shell, "ballistics"))
