# MConn-HelloWorld 0.0.5
# We will release the required documentations with the upcoming version 0.1.0.

MConnModule = require(require("path").join(process.env.MCONN_PATH, "bin/application/classes/MConnModule"))
Q = require("q")

class HelloWorld extends MConnModule

  timeout: 60000
    
  constructor: ->
    super("HelloWorld")
    
  init: (options, moduleRouter) ->
    Q = require("q")
    deferred = Q.defer()
    super(options, moduleRouter).then =>
      moduleRouter.get @createModuleRoute("custom"), (req, res) =>
        res.render(@getTemplatePath("custom"),
          modulename: @name
          activeSubmenu: "custom"
          mconnenv: req.mconnenv
        )
      fruits = ["Bananas", "Apple", "Blackberries", "Cranberries"]
      i = 0
      setInterval =>
        @getWebsocketHandler().then (io) ->
          if io
            fruitsSnippet = fruits.slice(0,i)
            i = (i + 1) % 4
            io.sockets.emit("updateHelloWorld", fruitsSnippet)
      , 1500

      moduleRouter.get @createModuleRoute("inventory"), (req, res) =>
        res.render(@getTemplatePath("inventory"),
          modulename: @name
          activeSubmenu: "inventory"
          mconnenv: req.mconnenv
        )
      @getWebsocketHandler().then (io) =>
        if io
          io.on("connection", (socket)=>
            @updateInventoryOnGui(socket)
          )

      Q.delay(500).then ->
        deferred.resolve()
    deferred.promise

  worker: (job, callback) ->
    @logger.logInfo("Starting worker for job " + job.data.fromMarathon.taskId + "_" + job.data.fromMarathon.taskStatus + " state: " + job.state)
    super(job, callback )
    .then (allreadyDoneState) =>
      if (allreadyDoneState)
        @allreadyDone(job, callback)
      else
        MConnModule.loadPresetForModule(job.data.fromMarathon.appId, @name)
        .then (modulePreset) =>
          unless modulePreset
            @noPreset(job, callback, "Preset could not be found for app #{job.data.fromMarathon.appId}")
          else
            @doWork(job, modulePreset, callback)
        .catch (error) =>
          @logger.logError("Error starting worker for #{@name} Module: " + error.toString() + ", " + error.stack)
          @failed(job, callback)

  doWork: (job, modulePreset, callback)->
    @logger.debug("INFO", "Processing job")
    Q.delay(1000).then =>
      path = job.data.fromMarathon.taskId
      switch job.data.fromMarathon.taskStatus
        when "TASK_RUNNING" then action = "add"
        when "TASK_FAILED", "TASK_KILLED", "TASK_FINISHED" then action = "remove"
      if action is "add"
        customData = modulePreset.options.actions.add
        promise = @addToZKInventory(path, customData, job)
      else if action is "remove"
        promise = @removeFromZKInventory(path)
      promise
      .then =>
        if action is "add" then @logger.logInfo(modulePreset.options.actions.add + " " + job.data.fromMarathon.taskId)
        if action is "remove" then @logger.logInfo(modulePreset.options.actions.remove + " " + job.data.fromMarathon.taskId)
        @success(job, callback)
        @updateInventoryOnGui()
      .catch (error) =>
        @failed(job, callback, error)

  cleanUpInventory: (result) ->
    @logger.debug("INFO", "Starting inventory cleanup")
    deferred = Q.defer()
    for m in result.missing
      m.data.fromMarathon.taskStatus = "TASK_RUNNING"
      @addJob(m, =>
        @logger.logInfo("Cleanup job " + m.data.fromMarathon.taskId + " successfully added")
      )
    for o in result.wrong
      o.data.fromMarathon.taskStatus = "TASK_KILLED"
      @addJob(o, =>
        @logger.logInfo("Cleanup job " + o.data.fromMarathon.taskId + " successfully removed")
      )
    @logger.logInfo("Cleanup initiated, added " + (result.wrong.length + result.missing.length) + " jobs")
    deferred.resolve()
    deferred.promise

module.exports = HelloWorld
