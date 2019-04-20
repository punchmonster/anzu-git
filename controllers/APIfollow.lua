local User  = require "models.user"

return function(self)

  local status, msg = User:follow(self.params.userHandle, self.params.followHandle)

  return { json = {
    sucess = status,
    message = msg
  } }
  --tostring(status) .. ": " .. msg
end
