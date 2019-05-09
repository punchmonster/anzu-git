local User  = require "models.user"

return function(self)


  return { redirect_to = self:url_for("login") }
  --tostring(status) .. ": " .. msg
end
