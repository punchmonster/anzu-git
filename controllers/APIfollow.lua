local User  = require "models.user"

return function(self)

  local status, msg
  if self.loggedIn == true then

    status, msg = User:follow(self.loggedUser[1].userHandle, self.params.followHandle)
  else
    status = false
    msg = "you're not logged in"
  end

  return { json = {
    sucess = status,
    message = msg
  } }
  --tostring(status) .. ": " .. msg
end
