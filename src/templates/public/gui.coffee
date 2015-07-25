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

this.app.controller 'HelloWorldPresetCtrl', [
  '$scope'
  '$rootScope'
  '$http'
  ($scope, $rootScope, $http) ->
    $scope.formdata = {}
    # SUBMIT ADD/EDIT FORM
    $scope.submit = ->
      unless (location.origin?)
        location.origin = location.protocol + "//" + location.host;
      json =
        appId: $scope.formdata.appId
        moduleName: "HelloWorld"
        status: if $scope.formdata.enabled then "enabled" else "disabled"
        options:
          actions:
            add: $scope.formdata.add
            remove: $scope.formdata.remove
      $http.post(location.origin + "/v1/module/preset", JSON.stringify(json))
      .success (data, status, headers, config) ->
        $scope.formdata = {}
        $("#preset-add").modal("hide")
      .error (data, status, headers, config) ->
        console.log data, status
    $scope.add = ->
      $scope.mode = "add"
      $scope.formdata = {}
      return
    $scope.edit = (preset) ->
      $scope.formdata.appId = preset.appId
      $scope.formdata.add = preset.options.actions.add
      $scope.formdata.remove = preset.options.actions.remove
      $scope.formdata.enabled = preset.status is "enabled"
      $scope.mode = "edit"
      return
    $scope.delete = ->
      unless (location.origin?)
        location.origin = location.protocol + "//" + location.host;
      json =
        appId: $scope.formdata.appId
        moduleName: "HelloWorld"
      $http(
        method: "DELETE"
        url: location.origin + "/v1/module/preset"
        params: json
      )
      .success (data, status, headers, config) ->
        $scope.formdata = {}
        $("#preset-add").modal("hide")
      .error (data, status, headers, config) ->
        console.log data, status
  ]
