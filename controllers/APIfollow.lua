local User  = require "models.user"

return function(self)

  User:follow(self.params.userHandle, self.params.followHandle)

  return "ok"
end
