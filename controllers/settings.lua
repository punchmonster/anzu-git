local csrf        = require "lapis.csrf"
local User        = require "models.user"


return {
  before = function(self)
    -- set header visibility
    self.header_vis = false
    -- Page title
    self.page_title = "User settings"
  end,

  GET = function(self)

    if self.loggedIn == true then

      -- generate token for page verification
      self.csrf_token = csrf.generate_token(self)
      self.submit_url = self:url_for("settings")

      return { render = "settings" }
    else
      return { redirect_to = self:url_for("login") }
    end
  end,

  POST = function(self)

    -- login
    if self.loggedIn == "true" then

      -- spam detection
      if #self.params.email > 1 then
        return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
      end

      -- check csrf protection
      csrf.assert_token(self)

      local status, msg, userID, sessionID = User:login(self.params.userHandle, self.params.userPassword)

      -- create cookie
      if status == true then
        self.session.userHandle = self.params.userHandle
      end

      return msg
    else

    end
  end
}
