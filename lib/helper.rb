# frozen_string_literal: true

module Helper
  # example:
  #    expr = "a = b + c"
  #     a, msg = eval_and_msg(expr, binding)
  def eval_and_msg(str, caller_binding)
    expr_value = caller_binding.eval(str)
    fstr = str.gsub(/(?<id>\w+)/, '%.2f (\k<id>)')
    value_array = str.scan(/(?<id>\w+)/).map{ |m | caller_binding.eval(m[0])}
    msg = format(fstr, *value_array)
    return expr_value, msg
  end




end
