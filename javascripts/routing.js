/**
 * Routing override for Netzke.Base.
 * @class Netzke.Core.Routing
 */
Ext.define('Netzke.Core.Routing', {
  override: 'Netzke.Base',

  netzkeAfterInitComponent: function(){
    if (this.netzkeRoutes) {
      var routes = this.netzkeGetRoutes();
      this.netzkeRouter = Ext.create('Ext.app.Controller', { routes: this.netzkeGetRoutes() });
      this.on('beforedestroy', this.netzkeCleanRoutes, this);

      this.on('render', function(){
        this.netzkeTriggerInitialRoute();
      });
    }

    this.callParent();
  },

  /**
   * Navigate to new hash route.
   * @method netzkeNavigateTo
   * @param route {String} Route
   * @param {Object} [options] Options:
   *   * **append** {Boolean} append to the current route
   *
   * @example
   *
   *     this.netzkeNavigateTo('user/1', {append: true})
   */
  netzkeNavigateTo: function(route, options){
    options = options || {};
    var newRoute = route;
    if (options.append) {
      newRoute = Ext.util.History.getToken() + "/" + newRoute;
    }
    Ext.util.History.add(newRoute);
  },

  // private

  netzkeCleanRoutes: function(){
    this.netzkeRouter.destroy();
  },

  netzkeTriggerInitialRoute: function(){
    var initToken = Ext.util.History.getToken();
    if (initToken) this.netzkeRouter.redirectTo(initToken, true);
  },

  netzkeGetRoutes: function(){
    var out = {};
    for (var route in this.netzkeRoutes) {
      var handlerName = this.netzkeRoutes[route],
          handler = this[handlerName];
      if (!handler) Netzke.exception("Route handler " + handlerName + " is not defined");
      out[route] = handler.bind(this);
    }
    return out;
  }
});
