local csrf        = require "lapis.csrf"
local User        = require "models.user"
local Text        = require "models.text"


return {
  before = function(self)
    -- set header visibility
    self.header_vis = false
    -- Page title
    self.page_title = "User settings"
    -- generate URL
    self.submit_url = self:url_for("settings")
  end,

  GET = function(self)

    if self.loggedIn == true then

      -- generate token for page verification
      self.csrf_token = csrf.generate_token(self)

      return { render = "settings" }
    else
      return { redirect_to = self:url_for("login") }
    end
  end,

  POST = function(self)

    -- login
    if self.loggedIn == true then

      -- spam detection
      if #self.params.email > 1 then
        return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
      end

      -- check csrf protection
      csrf.assert_token(self)

      if self.params.userGender == "default" then
        self.params.userGender = self.loggedUser[1].userGender
      end

      local x = {
        userID = self.loggedUser[1].userID,
        userName = self.params.userName,
        userHandle = self.params.userHandle,
        userGender = self.params.userGender,
        postImage = self.params.postImage,
        userAvatar = self.loggedUser[1].userAvatar
        --userBio = Text:post_sanitize(self.params.userBio, "http://yukku.org:8080")
      }

      local status = User:update(x)

      -- set current user handle to new userhandle if needed
      if status == true then
        self.session.userHandle = self.params.userHandle
      else
        return { redirect_to = self:url_for("error", { errorCode = status }) }
      end

      return "user settings saved"
    else
      return "you are not logged in"
    end
  end
}
