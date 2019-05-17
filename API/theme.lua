return function(self)
  if self.session.theme == "dark" then
    self.session.theme = "light"
  else
  	self.session.theme = "dark"
  end

  self.theme = self.session.theme

  return { json = {status = 0 }}
end
