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

    -- generate token for page verification
    self.csrf_token = csrf.generate_token(self)

    local currentID = nil
    if self.loggedIn then
      currentID = self.loggedUser[1].userID
    end
    -- retrieve timeline table
    local status
    status, self.profile_data, self.user_data = Posts:get_profile(self.params.userHandle, currentID)

    -- check if you're logged in and if so check following
    if self.loggedIn then
      local following = util.from_json(self.loggedUser[1].userFollowing)
      for k, v in pairs(following) do
        if v == self.user_data[1].userID then
          self.following = true
        end
      end
    end

    self.following_count = #util.from_json(self.user_data[1].userFollowing) - 1

    -- if linked to a thread retrieve thread data and push to view
    if self.params.postID ~= nil then
      self.posts_data = Posts:get_thread(self.params.postID, self.user_data[1].userID, currentID)
      self.threadID = self.posts_data[1].threadID

      if self.posts_data == false then
        self.params.postID = nil
        return { render = "profile" }
      end

      self.threadview = true
    end
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
      sessionID = self.loggedUser[1]['sessionID'],
      replyID = self.params.replyID,
      threadID = self.params.threadID
    }

    -- return post status
    local completed, error = Posts:submit(x)
    -- pass thread to model
    if completed == true then
      -- go back to feed view
      return { redirect_to = self:url_for("index") }
      --return { redirect_to = self:url_for("profile", { userHandle = self.params.userHandle, postID = self.params.postID }) }
    else
      return { redirect_to = self:url_for("error", { errorCode = error }) }
    end

  end
}
