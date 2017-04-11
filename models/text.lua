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

  -- match all "@<postnumber>" and store them in a table
  local post_links = {}
  for k in arg1:gmatch("@(%d+)") do
    table.insert(post_links, k)
  end

 -- replace all postnumber references with links
  for k, v in pairs(post_links) do
    arg1 = arg1:gsub("@" .. v, "<a href='" .. arg2 .. "/" .. v .. "'>&#64;" .. v  .. "</a>")
  end

  return arg1
end

return Text
