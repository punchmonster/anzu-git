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

function Text:APIKey(seed)
  local charset = {}

  -- qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890
  for i = 48,  57 do table.insert(charset, string.char(i)) end
  for i = 65,  90 do table.insert(charset, string.char(i)) end
  for i = 97, 122 do table.insert(charset, string.char(i)) end

  function string.random(length)
    math.randomseed(seed)

    if length > 0 then
      return string.random(length - 1) .. charset[math.random(1, #charset)]
    else
      return ""
    end
  end

  return string.random(64)

end

return Text
