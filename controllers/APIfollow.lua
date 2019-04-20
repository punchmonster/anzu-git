local User  = require "models.user"

return function(self)

  local status, msg = User:follow(self.params.userHandle, self.params.followHandle)

  return tostring(status) .. ": " .. msg
end
