options no_aot
require ecs
require ecs.common
require DagorConsole
require DagorSystem
require game.es.teleport_common
require game.es.truce_common
require DngNet


[console_cmd(name="truce.conclude")]
def console_truce_conclude(truce_id_a : int;
                           truce_id_b : int;
                           mutual : bool = true)
  conclude_truce(truce_id_a, truce_id_b, mutual)


[console_cmd(name="truce.break")]
def console_truce_break(truce_id_a : int;
                        truce_id_b : int;
                        mutual : bool = true)
  break_truce(truce_id_a, truce_id_b, mutual)


[console_cmd(name="truce.print")]
def console_truce_print()
  find_query() <| $ [es] (truce_controller__masks : UInt64List)
    var anyTruceFound = false
    for i in iter_range(truce_controller__masks)
      for b in range(TRUCE_MAX + 1)
        if (truce_controller__masks[i] & make_truce_mask(b)) != 0ul
          anyTruceFound = true
          console_print("{i} to {b}")

    if !anyTruceFound
      console_print("No truce found")

    return true

