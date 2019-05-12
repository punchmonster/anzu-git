local csrf        = require "lapis.csrf"
local Posts       = require "models.posts"
local User        = require "models.user"
local util        = require "lapis.util"

return {

  before = function(self)

    -- build url
    self.submit_url = self:url_for("index")
  end,

  GET = function(self)

    if self.loggedIn then
      self.user_data = self.loggedUser

      -- Page title
      self.page_title = self.loggedUser[1].userName .. " - notifications"

      local x = {
        notifType = "get_notif",
        userID    = self.loggedUser[1].userID
      }
      self.notif_status, self.posts_data = User:notifications(x)

      return { render = "notifications" }
    else
      return { redirect_to = self:url_for("login") }
    end
  end,

  POST = function(self)

    -- spam detection
    if #self.params.email > 1 then
      return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
    end

    --[[ check if person is banned
    if Bans:check(ngx.var.remote_addr) then
      return { redirect_to = self:url_for("index") }
    end]]

    -- check csrf protection
    csrf.assert_token(self)

    -- posting configuration
    local x = {
      userID = self.session.current_user,
      replyID = self.params.replyID,
      threadID = self.params.threadID,
      postBody = self.req.params_post.postBody,
      postImage = self.params.postImage,
      sessionID = self.loggedUser[1].sessionID
    }

    -- return post status
    local completed, error = Posts:submit(x)
    -- pass thread to model
    if completed == true then
      -- go back to feed view
      return { redirect_to = self:url_for("index") }
    else
      return { redirect_to = self:url_for("error", { errorCode = error }) }
    end

  end
}
