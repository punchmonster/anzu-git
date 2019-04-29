local util         = require("lapis.html").escape
local Model        = require ("lapis.db.model").Model
local Text         = Model:extend("text")


-- FUNCTION: processes the post body for storage
-- arg1: post body / arg2: feed name
-- RETURN: string ready for storing
function Text:post_sanitize(arg1, arg2)

  -- filter these characters
  local replacements = {
    ['&' ] = '&amp;',
    ['<' ] = '&lt;',
    ['>' ] = '&gt;',
    ['"' ] = '&quot;',
    ['\n'] = '<br/>'
  }

  arg1 = arg1:gsub('[&<>"\n]', replacements)

  -- replace all postnumber references with links
  arg1 = arg1:gsub("@([%w_]+)", "<a href='" .. arg2 .. "/%1'>@%1</a>")

  return arg1
end

return Text
