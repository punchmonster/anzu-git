local csrf        = require "lapis.csrf"
local Feeds       = require "models.feeds"

return {
  before = function(self)
    -- get feeds for navigation
    self.nav_data = Feeds:get_all()
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
    -- spam detection
    if #self.params.email > 1 then
      return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
    end

    -- check username and password length + formatting
    if #self.params.userHandle > 12 then
      return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
    end

    if #self.params.userPassword < 7 then
      return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
    end

    -- check csrf protection
    csrf.assert_token(self)

    User:create(self.params.userHandle, self.params.userPassword)
  end
}
