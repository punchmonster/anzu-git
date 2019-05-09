local Posts  = require "models.posts"
local User   = require "models.user"

return function(self)

  -- declare default response values
  local status, msg

  -- check what API options are requested
  if self.params.option == "get_timeline" then
    if self.loggedIn == true then
      timeline = Posts:get_timeline(util.from_json(self.loggedUser[1].userFollowing), self.loggedUser[1].userID)
    else
      timeline = "you are not logged in"
    end
  end

  return { json = timeline }
end
