Replicator = require './replicator/main'
LayoutView = require './views/layout'
ServiceManager = require './service/service_manager'
Notifications = require '../views/notifications'

module.exports =

    initialize: ->
        window.app = this

        # Monkey patch for browser debugging
        if window.isBrowserDebugging
            window.navigator = window.navigator or {}
            window.navigator.globalization = window.navigator.globalization or {}
            window.navigator.globalization.getPreferredLanguage = (callback) -> callback value: 'fr-FR'


        navigator.globalization.getPreferredLanguage (properties) =>
            [@locale] = properties.value.split '-'

            @polyglot = new Polyglot()
            locales = try require 'locales/'+ @locale
            catch e then require 'locales/en'

            @polyglot.extend locales
            window.t = @polyglot.t.bind @polyglot

            Router = require 'router'
            @router = new Router()

            @replicator = new Replicator()
            @layout = new LayoutView()

            @replicator.init (err, config) =>
                if err
                    console.log err, err.stack
                    return alert err.message or err

                @notificationManager = new Notifications()
                @serviceManager = new ServiceManager()

                $('body').empty().append @layout.render().$el
                Backbone.history.start()

                if config.remote
                    app.regularStart()

                else
                    # App's first start
                    @router.navigate 'login', trigger: true

    regularStart: ->
        app.foreground = true

        document.addEventListener "resume", =>
            console.log "RESUME EVENT"
            app.foreground = true
            if app.backFromOpen
                app.backFromOpen = false
                app.replicator.startRealtime()
            else
                app.replicator.backup()
        , false
        document.addEventListener "pause", =>
            console.log "PAUSE EVENT"
            app.foreground = false
            app.replicator.stopRealtime()

        , false
        document.addEventListener 'offline', ->
            device_status = require './lib/device_status'
            device_status.update()
        , false
        document.addEventListener 'online', ->
            device_status = require './lib/device_status'
            device_status.update()
            backup = () ->
                app.replicator.backup(true)
                window.removeEventListener 'realtime:onChange', backup, false
            window.addEventListener 'realtime:onChange', backup, false
        , false

        @router.navigate 'folder/', trigger: true
        @router.once 'collectionfetched', =>
            app.replicator.backup()
