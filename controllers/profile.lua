local csrf        = require "lapis.csrf"
local Posts       = require "models.posts"
local Text        = require "models.text"
local Bans        = require "models.bans"
local User        = require "models.user"
local util        = require "lapis.util"

return {

  before = function(self)
    -- Page title
    self.page_title = "profile"

    -- build url
    self.submit_url = self:url_for("index")
  end,

  GET = function(self)

    if self.loggedIn then

    end

    if self.params.postID ~= nil then
      -- generate token for page verification
      self.csrf_token = csrf.generate_token(self)
    end

    -- retrieve timeline table
    local status
    status, self.profile_data, self.user_data = Posts:get_profile(self.params.userHandle)
    return { render = "profile" }
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
      postBody = self.req.params_post['postBody'],
      postImage = self.params.postImage,
      sessionID = self.loggedUser[1]['sessionID']
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
