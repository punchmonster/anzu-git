local Posts  = require "models.posts"

return function(self)

  -- declare default response values
  local status, msg

  -- check what API options are requested
  if self.params.option == "modify" then
    if self.loggedIn == true then

      -- execute action with supplied userID and postID
      if self.params.ID ~= nil then
        status, msg = Posts:like_post(self.loggedUser[1].userID, ID)
      end
    else
      status = false
      msg = "you're not logged in"
    end
  end

  return { json = {
    sucess = status,
    message = msg
  } }
end
