local User  = require "models.user"

return function(self)

  function User:follow(self.params.userHandle, self.params.followHandle)

  return { render = "error_404", status = "404" }
end
