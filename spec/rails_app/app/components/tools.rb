class Tools < Netzke::Base
  def configure(c)
    super
    c.tools = [
      { type: :refresh, handler: f(:handle_refresh) },
      { type: :gear, handler: f(:on_gear) }
    ]
  end

  js_configure do |c|
    c.handle_refresh = <<-JS
      function(){
        this.setTitle("Refresh tool clicked");
      }
    JS

    c.on_gear = <<-JS
      function(){
        this.setTitle("Gear tool clicked")
      }
    JS
  end
end
