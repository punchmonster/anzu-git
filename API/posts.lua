local Posts  = require "models.posts"
local User   = require "models.user"
local util   = require "lapis.util"

return function(self)

  -- declare default response values
  local status, msg

  -- check what API options are requested
  if self.params.option == "get_timeline" then

    -- check if user is logged in and if so retrieve personal timeline data
    if self.loggedIn == true then
      if self.params.ID ~= nil then
        self.params.ID = tonumber(self.params.ID)
      end
      timeline = Posts:get_timeline(util.from_json(self.loggedUser[1].userFollowing), self.loggedUser[1].userID, self.params.ID)
    else
      timeline = "you are not logged in"
    end
  end

  return { json = timeline }
end
