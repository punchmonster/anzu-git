local Posts  = require "models.posts"
local User   = require "models.user"
local util   = require "lapis.util"

return function(self)

  -- declare default response values
  local output, msg, status

  -- check what API options are requested
  if self.params.option == "get_timeline" then

    -- check if user is logged in and if so retrieve personal timeline data
    if self.loggedIn == true then
      if self.params.ID ~= nil then
        self.params.ID = tonumber(self.params.ID)
      end
      output = Posts:get_timeline(util.from_json(self.loggedUser[1].userFollowing), self.loggedUser[1].userID, self.params.ID)
    else
      output = "you are not logged in"
    end
  elseif self.params.option == "get_profile" then

    local currentID = nil
    if self.loggedIn == true then
      currentID = self.loggedUser[1].userID
    end

    status, output = Posts:get_profile(self.params.ID, currentID, self.params.ID2)
  end

  return { json = output }
end
