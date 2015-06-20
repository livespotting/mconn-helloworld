# MConn-HelloWorld 0.0.5
# We will release the required documentations with the upcoming version 0.1.0.

Module = require(require("path").join(process.env.MCONN_PATH, "bin/classes/Module"))
Q = require("q")

class HelloWorld extends Module

  timeout: 60000

  constructor: ->
    super("HelloWorld")

  init: (options, moduleRouter, folder) ->
    Q = require("q")
    deferred = Q.defer()
    super(options, moduleRouter, folder).then =>
      moduleRouter.get @createModuleRoute("custom"), (req, res) =>
        res.render(@getTemplatePath("custom"),
          modulename: @name
          activeSubmenu: "custom"
        )
      fruits = ["Bananas", "Apple", "Blackberries", "Cranberries"]
      i = 0
      setInterval =>
        @getWebsocketHandler().then (io) ->
          if io
            fruitsSnippet = fruits.slice(0,i)
            i = (i + 1) % 4
            io.of("/HelloWorld").emit("updateHelloWorld", fruitsSnippet)
      , 1500
      moduleRouter.get @createModuleRoute("inventory"), (req, res) =>
        res.render(@getTemplatePath("inventory"),
          modulename: @name 
          activeSubmenu: "inventory"
          mconnenv: req.mconnenv
        )
      @getWebsocketHandler().then (io) =>
        if io
          nsp = io.of("/HelloWorld")
          nsp.on("connection", (socket)=>
            @updateInventoryOnGui(socket)
          )
      Q.delay(500).then ->
        deferred.resolve()
    deferred.promise

  worker: (taskData, callback) ->
    @logger.info("Starting worker for task " + taskData.getData().taskId + "_" + taskData.getData().taskStatus + " state: " + taskData.state)
    super(taskData, callback )
    .then (allreadyDoneState) =>
      if (allreadyDoneState)
        @allreadyDone(taskData, callback)
      else
        Module.loadPresetForModule(taskData.getData().appId, @name)
        .then (modulePreset) =>
          unless modulePreset
            @noPreset(taskData, callback, "Preset could not be found for app #{taskData.getData().appId}")
          else
            @doWork(taskData, modulePreset, callback)
        .catch (error) =>
          @logger.error("Error starting worker for #{@name} Module: " + error.toString() + ", " + error.stack)
          @failed(taskData, callback)

  doWork: (taskData, modulePreset, callback)->
    @logger.debug("INFO", "Processing task")
    Q.delay(if process.env.MCONN_MODULE_HELLOWORLD_RUNTIME then process.env.MCONN_MODULE_HELLOWORLD_RUNTIME else 1000).then =>
      path = taskData.getData().taskId
      switch taskData.getData().taskStatus
        when "TASK_RUNNING" then action = "add"
        when "TASK_FAILED", "TASK_KILLED", "TASK_FINISHED" then action = "remove"
      if action is "add"
        customData = modulePreset.options.actions.add
        promise = @addToZKInventory(path, customData, taskData)
      else if action is "remove"
        promise = @removeFromZKInventory(path)
      promise
      .then =>
        if action is "add" then @logger.info(modulePreset.options.actions.add + " " + taskData.getData().taskId)
        if action is "remove" then @logger.info(modulePreset.options.actions.remove + " " + taskData.getData().taskId)
        @success(taskData, callback)
        @updateInventoryOnGui()
      .catch (error) =>
        @failed(taskData, callback, error)

  cleanUpInventory: (result) ->
    @logger.debug("INFO", "Starting inventory cleanup")
    deferred = Q.defer()
    for m in result.missing
      m.taskStatus = "TASK_RUNNING"
      @addTask(m, =>
        @logger.info("Cleanup task " + m.getData().taskId + " successfully added")
      )
    for o in result.wrong
      o.taskStatus = "TASK_KILLED"
      @addTask(o, =>
        @logger.info("Cleanup task " + o.getData().taskId + " successfully removed")
      )
    @logger.info("Cleanup initiated, added " + (result.wrong.length + result.missing.length) + " tasks")
    deferred.resolve()
    deferred.promise

module.exports = HelloWorld
