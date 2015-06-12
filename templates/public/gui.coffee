this.app.config [
  '$routeProvider',
  ($routeProvider) ->
    $routeProvider.when('/modules/HelloWorld/main',
      templateUrl: 'modules/HelloWorld/main'
      controller: 'HelloWorldCtrl')
    $routeProvider.when('/modules/HelloWorld/presets',
      templateUrl: 'modules/HelloWorld/presets'
      controller: 'HelloWorldCtrl')
    $routeProvider.when('/modules/HelloWorld/queue',
      templateUrl: 'modules/HelloWorld/queue'
      controller: 'HelloWorldCtrl')
]

this.app.controller 'HelloWorldCtrl', [
  '$scope'
  '$rootScope'
  ($scope, $rootScope) ->
    unless $scope.webSocketEventsAreBinded
        if $rootScope.socket then $rootScope.socket.disconnect()
        $rootScope.socket = window.connectToNamespace("HelloWorld", $rootScope)
        $rootScope.socket.on "updateHelloWorld", (data) ->
          $scope.$apply ->
            $scope.helloworlddata = data
        $rootScope.socket.on "updateHelloWorldInventory", (data) ->
          $scope.$apply ->
            $scope.inventory = data
        $rootScope.socket.on "updatePresets", (data) ->
          $scope.$apply ->
            $scope.presets = data
        $rootScope.socket.on "updateHelloWorldQueue", (data) ->
            $scope.$apply ->
              $scope.queue = data.queue
              $scope.queuelength = data.queuelength
        $scope.webSocketEventsAreBinded = true
]
