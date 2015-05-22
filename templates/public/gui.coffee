this.app.controller 'HelloWorldCtrl', [
  'ws'
  '$scope'
  (ws, $scope) ->
    ws.on "updateHelloWorld", (data) ->
      $scope.helloworlddata = data
    ws.on "updateHelloWorldInventory", (data) ->
      $scope.inventory = data
    ws.on "updateHelloWorldQueue", (data) ->
      $scope.queue = data.queue
      console.log data.queue
      $scope.queuelength = data.queuelength
  ]
