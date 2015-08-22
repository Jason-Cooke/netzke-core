module Netzke::Core
  # Any Netzke component can define child components, which can either be statically nested in the compound layout (e.g. as different regions of the 'border' layout), or dynamically loaded at a request (as is the advanced search panel in Basepack::GridPanel, for example).
  #
  # == Defining a component
  #
  # You can define a child component by calling the +component+ class method which normally requires a block:
  #
  #     component :users do |c|
  #       c.klass = GridPanel
  #       c.model = "User"
  #       c.title = "Users"
  #     end
  #
  # If no configuration is required, and the component's class name can be derived from its name, then the block can be omitted, e.g.:
  #
  #     component :user_grid
  #
  # which is equivalent to:
  #
  #     component :user_grid do |c|
  #       c.klass = UserGrid
  #     end
  #
  # == Overriding a component
  #
  # When overriding a component, the `super` method should be called, with the configuration object passed to it as parameter:
  #
  #     component :users do |c|
  #       super(c)
  #       c.title = "Modified Title"
  #     end
  #
  # == Referring to components in layouts
  #
  # A child component can be referred in the layout by using symbols:
  #
  #     component :users do |c|
  #       c.title = "A Netzke component"
  #     end
  #
  #     def configure(c)
  #       super
  #       c.items = [
  #         { xtype: :panel, title: "Simple Ext panel" },
  #         :users # a Netzke component
  #       ]
  #     end
  #
  # If an extra (layout) configuration should be provided, a component can be referred to by using the +component+ key in the configuration hash (this can be useful when overriding a layout of a child component):
  #
  #     component :tab_one # ...
  #     component :tab_two # ...
  #
  #     def configure(c)
  #       super
  #       c.items = [
  #         {component: :tab_one, title: "One"},
  #         {component: :tab_two, title: "Two"}
  #       ]
  #     end
  #
  # == Lazily vs eagerly loaded components
  #
  # By default, if a component is not used in the layout, it is lazily loaded, which means that the code for this component is not loaded in the browser until the moment the component gets dynamically loaded by the JavaScript method `netzkeLoadComponent` (see {Netzke::Core::Javascript}). Referring a component in the layout (the `items` property) automatically makes it eagerly loaded. Sometimes it's desired to eagerly load a component without using it directly in the layout (an example can be a window that we need to render instantly without requesting the server). In this case an option `eager_loading` can be set to true:
  #
  #     component :eagerly_loaded_window do |c|
  #       c.klass = SomeWindowComponent
  #       c.eager_loading = true
  #     end
  #
  # == Dynamic component loading
  #
  # Child components can be dynamically loaded by using client class' +netzkeLoadComponent+ method (see {javascript/ext.js}[https://github.com/netzke/netzke-core/blob/master/javascripts/ext.js] for inline documentation):
  #
  # == Excluded components
  #
  # You can make a child component inavailable for dynamic loading by using the +excluded+ option. When an excluded component is used in the layout, it will be skipped.
  # This can be used for authorization.
  module Composition
    extend ActiveSupport::Concern

    included do
      # Declares Base.component, for declaring child componets, and Base#components, which returns a [Hash] of all component configs by name
      declare_dsl_for :components, config_class: Netzke::Core::ComponentConfig

      attr_accessor :components_in_config

      # Loads a component on browser's request. Every Netzke component gets this endpoint.
      # +params+ should contain:
      #   [cache] an array of component classes cached at the browser
      #   [name] name of the child component to be loaded
      #   [index] clone index of the loaded component
      endpoint :deliver_component do |params|
        cache = params[:cache].split(",") # array of cached xtypes
        component_name = params[:name].underscore.to_sym

        item_id = params[:item_id]

        cmp_instance = components[component_name] &&
          !components[component_name][:excluded] &&
          component_instance(component_name, {item_id: item_id, client_config: params[:client_config]})

        if cmp_instance
          js, css = cmp_instance.js_missing_code(cache), cmp_instance.css_missing_code(cache)
          { js: js, css: css, config: cmp_instance.js_config }
        else
          { error: "Couldn't load component '#{component_name}'" }
        end
      end

    end # included

    # @return [Hash] configs of eagerly loaded components by name
    def eagerly_loaded_components
      @eagerly_loaded_components ||= components.select{|k,v| components_in_config.include?(k) || v[:eager_loading]}
    end

    # Instantiates a child component by its name.
    # +params+ can contain:
    #   [client_config] a config hash passed from the client class
    #   [item_id] overridden item_id (used in case of multi-instance loading)
    def component_instance(name, options = {})
      if respond_to?(:"#{name}_component")
        cfg = ComponentConfig.new(name, self)
        cfg.client_config = options[:client_config] || {}
        cfg.item_id = options[:item_id]
        cfg.js_id = options[:js_id]
        send("#{name}_component", cfg)
        cfg.set_defaults!
      else
        cfg = ComponentConfig.new(name, self)
        cfg.merge!(components[name.to_sym])
      end

      component_instance_from_config(cfg) if cfg
    end

    def component_instance_from_config(c)
      klass = c.klass || c.class_name.constantize
      klass.new(c, self)
    end

    # @return [Array<Class>] All component classes that we depend on (used to render all necessary javascripts and stylesheets)
    def dependency_classes
      res = []

      eagerly_loaded_components.keys.each do |aggr|
        res += component_instance(aggr).dependency_classes
      end

      res += self.class.netzke_ancestors
      res.uniq
    end

    def extend_item(item)
      item = detect_and_normalize_component(item)
      components_in_config << item[:netzke_component] if include_component?(item)
      super item
    end

  private

    def include_component?(cmp_config)
      cmp_config.is_a?(Hash) &&
        cmp_config[:netzke_component] &&
        cmp_config[:eager_loading] != false &&
        !cmp_config[:excluded]
    end

    def detect_and_normalize_component(item)
      item = {component: item} if item.is_a?(Symbol) && components[item]
      if item.is_a?(Hash) && component_name = item[:component]
        cfg = components[component_name]
        cfg.merge!(item)
        if cfg[:excluded]
          {excluded: true}
        else
          # cfg.merge(item).merge(netzke_component: item.delete(:component))
          item.merge(netzke_component: cfg[:component]) # TODO: TEST THIS
        end
      elsif item.is_a?(Hash) && (item[:klass] || item[:class_name])
        # declare component on the fly
        component_name = :"component_#{@implicit_component_index += 1}"
        components[component_name] = item.merge(eager_loading: true) unless item[:excluded]
        {netzke_component: component_name}
      else
        item
      end
    end
  end
end
