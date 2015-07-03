# MConn-HelloWorld 0.0.9
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
    super(options, moduleRouter, folder)
    .then =>
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
      deferred.resolve()
    .catch (error) =>
      @logger.error error
    deferred.promise

  on_TASK_RUNNING: (taskData, modulePreset, callback) ->
    delay = if process.env.MCONN_DEV_HELLOWORLD_WORKINGTIME then process.env.MCONN_DEV_HELLOWORLD_WORKINGTIME else 250
    Q.delay(delay)
    .then =>
      path = taskData.getData().taskId
      customData = modulePreset.options.actions.add
      return @addToZKInventory(path, customData, taskData)
    .then =>
      @logger.info(modulePreset.options.actions.add + " " + taskData.getData().taskId)
      @success(taskData, callback)
      @updateInventoryOnGui()
    .catch (error) =>
      @failed(taskData, callback, error)

  on_TASK_FAILED: (taskData, modulePreset, callback) ->
    delay = if process.env.MCONN_DEV_HELLOWORLD_WORKINGTIME then process.env.MCONN_DEV_HELLOWORLD_WORKINGTIME else 250
    Q.delay(delay)
    .then =>
      path = taskData.getData().taskId
      @removeFromZKInventory(path)
    .then =>
      @logger.info(modulePreset.options.actions.remove + " " + taskData.getData().taskId)
      @success(taskData, callback)
      @updateInventoryOnGui()
    .catch (error) =>
      @failed(taskData, callback, error)

  on_TASK_KILLED: (taskData, modulePreset, callback) ->
    @on_TASK_FAILED(taskData, modulePreset, callback)

  on_TASK_FINISHED: (taskData, modulePreset, callback) ->
    @on_TASK_FAILED(taskData, modulePreset, callback)

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
