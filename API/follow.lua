local User  = require "models.user"

return function(self)

  -- check if user is logged in
  local status, msg
  if self.loggedIn == true then

    -- check to add or remove the follow then execute action
    local follow = true
    if self.params.toggle == "remove" then
      follow = false
    end

    status, msg = User:follow(self.loggedUser[1].userHandle, self.params.followHandle, follow)
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
