local Posts  = require "models.posts"
local User   = require "models.user"
local util   = require "lapis.util"

return function(self)

  -- declare default response values
  local status, msg

  -- check what API options are requested
  if self.params.option == "get_timeline" then
    if self.loggedIn == true then
      timeline = Posts:get_timeline(util.from_json(self.loggedUser[1].userFollowing), self.loggedUser[1].userID, tonumber(self.params.ID))
    else
      timeline = "you are not logged in"
    end
  end

  return { json = timeline }
end
