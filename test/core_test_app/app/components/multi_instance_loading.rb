# Subsequent loading of tabs should result in functional "tab" component instances
class MultiInstanceLoading < Netzke::Base
  js_configure do |c|
    c.extend = "Ext.tab.Panel"
    c.mixin
  end

  action :load_hello_user
  action :load_composition

  component :hello_user do |c|
    # client_config is accessible here
    client_config = c.client_config || {}
    c.user = client_config[:user]
  end

  component :composition

  def configure(c)
    super
    c.bbar = [:load_hello_user, :load_composition]
  end
end
