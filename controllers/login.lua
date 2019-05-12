local csrf        = require "lapis.csrf"
local User        = require "models.user"


return {
  before = function(self)
    -- set header visibility
    self.header_vis = false
    -- Page title
    self.page_title = "login"
  end,

  GET = function(self)

    -- generate token for page verification
    self.csrf_token = csrf.generate_token(self)
    self.submit_url = self:url_for("login")

    return { render = "login" }
  end,

  POST = function(self)

    print(self.params.login)
    -- login
    if self.params.login == "true" then

      -- spam detection
      if #self.params.email > 1 then
        return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
      end

      -- check csrf protection
      csrf.assert_token(self)

      -- log user in
      local status, msg, userID, sessionID = User:login(self.params.userHandle, self.params.userPassword)

      -- create cookie
      if status == true then
        self.session.userHandle = self.params.userHandle
        self.session.current_user = userID
        self.session.sessionID = sessionID
      end

      return { redirect_to = self:url_for("index") }
    else

      -- user sign up

      -- spam detection
      if #self.params.email > 1 then
        return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
      end

      -- check username and password length + formatting
      if #self.params.userHandle < 3 or #self.params.userHandle > 15 then
        return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
      end

      if #self.params.userPassword < 7 or #self.params.userPassword > 64 then
        return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
      end

      -- check csrf protection
      print(csrf.assert_token(self))

      -- verification
      local status, msg = User:create(string.match(self.params.userHandle, '^[A-Za-z0-9_-]+'), self.params.userPassword)
      return msg
    end
  end
}
