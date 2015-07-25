'use strict'

module.exports = (grunt) ->
  watchFiles =
    clientJS: [ '*.js', 'bin/template/public/*.js' ]
    clientCoffeeScript: [ 'src/*.coffee', 'src/template/public/*.coffee' ]
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    watch:
      clientCoffeeScript:
        files: watchFiles.clientCoffeeScript
        tasks: [
          'loadConfig'
          'lint'
          'copy'
          'shell:compileCoffee'
          'ngAnnotate'
          'uglify'
        ]
        options: livereload: true
    coffeelint:
      app: [ '*.coffee' ]
      options:
        configFile: 'coffeelint.json'
        reporter: 'checkstyle'
    env:
      development: NODE_ENV: 'development'
      production: NODE_ENV: 'production'
    concurrent:
      default: [
        'watch'
        'nodemon'
      ]
      debug: [
        'nodemon'
        'watch'
        'node-inspector'
      ]
      options:
        logConcurrentOutput: true
        limit: 10
    shell:
      clear: command: 'rm -Rf build && mkdir build && echo "removed build\ncreated build directory"'
      executeCoffeelint: command: 'coffeelint -f coffeelint.json --reporter checkstyle src/ > build/checkstyle-result.xml'
      mocha_tests: command: 'mocha --timeout=5000 --compilers coffee:coffee-script/register'
      mocha_tests_silent: command: 'export LOGGER_MUTED=true && mocha --timeout=5000 --compilers coffee:coffee-script/register'
      mocha_tests_xunit: command: 'export LOGGER_MUTED=true && mocha --timeout=5000 --compilers coffee:coffee-script/register -R xunit > build/xunit.xml'
      mocha_tests_cov: command: 'export LOGGER_MUTED=true && mocha --timeout=5000 --compilers coffee:coffee-script/register --require coffee-coverage/register-istanbul && istanbul report && istanbul report cobertura'
  # Load NPM tasks
  require('load-grunt-tasks') grunt
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-concurrent'
  grunt.loadNpmTasks 'grunt-nodemon'
  # Making grunt default to force in order not to break the project.
  grunt.option 'force', true
  grunt.task.registerTask 'loadConfig', 'Task that loads the config into a grunt option.', ->
    grunt.config.set 'applicationJavaScriptFiles', watchFiles.clientJS
    grunt.config.set 'applicationCSSFiles', watchFiles.clientCSS
    return
  # Execute checkstyle file from coffeelint
  grunt.registerTask 'checkstyle', [ 'shell:executeCoffeelint' ]
  # Default task
  grunt.registerTask 'default', [
    'shell:clear'
    'loadConfig'
    'lint'
    'concurrent:default'
  ]
  # Lint task(s).
  grunt.registerTask 'lint', [
    'shell:clear'
    'coffeelint'
    'checkstyle'
  ]
  # Build task(s).
  grunt.registerTask 'build', [
    'shell:clear'
    'loadConfig'
    'lint'
  ]
  # Test task(s).
  grunt.registerTask 'test', [
    'shell:mocha_tests'
  ]
  # Run mocha without process-logging.
  grunt.registerTask 'test-silent', [
    'shell:mocha_tests_silent'
  ]
  # Build and test task(s).
  grunt.registerTask 'dev', [
    'build'
    'shell:mocha_tests'
  ]
  # Test task(s) and create xUnit.xml.
  grunt.registerTask 'test-xunit', [
    'shell:mocha_tests_xunit'
  ]
  # Test task(s) and create cov.-report.
  grunt.registerTask 'test-cov', [
    'shell:mocha_tests_cov'
  ]
  return
