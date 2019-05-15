local User = require "models.user"

return {
  POST = function(self)

    -- username and password correct?
  	local status, msg, userID, sessionID = User:login(self.params.userHandle, self.params.userPassword)

  	if status == true then
      -- give keys
  		local key = User:key(self.params.userHandle)
  		return { json = {
  			success = 1,
  			key = key,
  			handle = userHandle,
  			id = userID
  		}}
  	else
      -- fuck off
  		return { json = {
  			success = 0
  		}}
  	end
  end
}
