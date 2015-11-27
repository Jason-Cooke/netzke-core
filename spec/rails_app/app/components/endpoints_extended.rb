class EndpointsExtended < Endpoints
  def configure(c)
    super
    c.title = "Endpoints Extended"
  end

  action :with_response do |c|
    c.text = "With extended response"
  end

  client_class do |c|
    c.on_bug_server = <<-JS
      function(){
        this.callParent();
        var bottomBar = this.getDockedItems()[1] || this.getDockedItems()[0]; // Hacky-hacky... better way to surely get the bottom bar?
        bottomBar.add({text: "Added" + " by extended Server Caller"});
      }
    JS
  end

  # Overriding the :whats_up endpoint from ServerCaller
  endpoint :whats_up do |greeting|
    super greeting

    this.set_title(this.set_title[0] + " plus")
  end
end
