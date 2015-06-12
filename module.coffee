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

  worker: (job, callback) ->
    @logger.info("Starting worker for job " + job.data.fromMarathonEvent.taskId + "_" + job.data.fromMarathonEvent.taskStatus + " state: " + job.state)
    super(job, callback )
    .then (allreadyDoneState) =>
      if (allreadyDoneState)
        @allreadyDone(job, callback)
      else
        Module.loadPresetForModule(job.data.fromMarathonEvent.appId, @name)
        .then (modulePreset) =>
          unless modulePreset
            @noPreset(job, callback, "Preset could not be found for app #{job.data.fromMarathonEvent.appId}")
          else
            @doWork(job, modulePreset, callback)
        .catch (error) =>
          @logger.error("Error starting worker for #{@name} Module: " + error.toString() + ", " + error.stack)
          @failed(job, callback)

  doWork: (job, modulePreset, callback)->
    @logger.debug("INFO", "Processing job")
    Q.delay(1000).then =>
      path = job.data.fromMarathonEvent.taskId
      switch job.data.fromMarathonEvent.taskStatus
        when "TASK_RUNNING" then action = "add"
        when "TASK_FAILED", "TASK_KILLED", "TASK_FINISHED" then action = "remove"
      if action is "add"
        customData = modulePreset.options.actions.add
        promise = @addToZKInventory(path, customData, job)
      else if action is "remove"
        promise = @removeFromZKInventory(path)
      promise
      .then =>
        if action is "add" then @logger.info(modulePreset.options.actions.add + " " + job.data.fromMarathonEvent.taskId)
        if action is "remove" then @logger.info(modulePreset.options.actions.remove + " " + job.data.fromMarathonEvent.taskId)
        @success(job, callback)
        @updateInventoryOnGui()
      .catch (error) =>
        @failed(job, callback, error)

  cleanUpInventory: (result) ->
    @logger.debug("INFO", "Starting inventory cleanup")
    deferred = Q.defer()
    for m in result.missing
      m.data.fromMarathonEvent.taskStatus = "TASK_RUNNING"
      @addJob(m, =>
        @logger.info("Cleanup job " + m.data.fromMarathonEvent.taskId + " successfully added")
      )
    for o in result.wrong
      o.data.fromMarathonEvent.taskStatus = "TASK_KILLED"
      @addJob(o, =>
        @logger.info("Cleanup job " + o.data.fromMarathonEvent.taskId + " successfully removed")
      )
    @logger.info("Cleanup initiated, added " + (result.wrong.length + result.missing.length) + " jobs")
    deferred.resolve()
    deferred.promise

module.exports = HelloWorld
