local Posts  = require "models.posts"

return function(self)

  -- declare default response values
  local status, msg

  -- check what API options are requested
  if self.params.option == "modify" then
    if self.loggedIn == true then

      -- execute action with supplied userID and postID
      if self.params.ID ~= nil then
        status, msg = Posts:tag_post(self.loggedUser[1].userID, self.params.ID)
      end
    else
      status = false
      msg = "you're not logged in"
    end
  end

  x = {
    notifType = "tag",
    postID = self.params.ID,
    targetID = 0,
    userID = self.loggedUser[1].userID,
    notifTime = ngx.time()
  }

  User:notifications(x)

  return { json = {
    success = status,
    message = "TAG: " .. msg
  } }
end
