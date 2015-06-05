this.app.controller 'HelloWorldCtrl', [
  'ws'
  '$scope'
  (ws, $scope) ->
    unless $scope.webSocketEventsAreBinded
        ws.on "updateHelloWorld", (data) ->
            $scope.helloworlddata = data
        ws.on "updateHelloWorldInventory", (data) ->
            $scope.inventory = data
        ws.on "updateHelloWorldQueue", (data) ->
            $scope.queue = data.queue
            $scope.queuelength = data.queuelength
        $scope.webSocketEventsAreBinded = true


  ]
