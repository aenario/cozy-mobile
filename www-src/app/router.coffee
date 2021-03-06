app = require 'application'
FolderView = require './views/folder'
LoginView = require './views/login'
DeviceNamePickerView = require './views/device_name_picker'
FirstSyncView = require './views/first_sync'
ConfigView = require './views/config'
FolderCollection = require './collections/files'

module.exports = class Router extends Backbone.Router

    routes:
        'folder/*path'                    : 'folder'
        'search/*query'                   : 'search'
        'login'                           : 'login'
        'device-name-picker'              : 'deviceNamePicker'
        'first-sync'                      : 'firstSync'
        'config'                          : 'config'

    folder: (path) ->
        $('#btn-menu').show()
        $('#btn-back').hide()
        app.layout.setBreadcrumbs path

        collection = new FolderCollection [], path: path
        @display new FolderView {collection},
        collection.fetch()
        collection.once 'fullsync', => @trigger 'collectionfetched'

    search: (query) ->
        $('#btn-menu').show()
        $('#btn-back').hide()
        app.layout.setBackButton '#folder/', 'home'
        app.layout.setTitle t('search') + ' "' + query + '"'

        collection = new FolderCollection [], query: query
        @display new FolderView {collection}
        collection.search (err) =>
            if err
                console.log err.stack
                return alert(err)

            $('#search-input').blur() # close keyboard

    login: ->
        app.layout.setTitle t 'setup 1/3'
        $('#btn-menu, #btn-back').hide()
        @display new LoginView()

    deviceNamePicker: ->
        app.layout.setTitle t 'setup 2/3'
        @display new DeviceNamePickerView()

    firstSync: ->
        app.layout.setTitle t 'setup end'
        @display new FirstSyncView()

    config: ->
        $('#btn-back').hide()
        titleKey = if app.isFirstRun then 'setup 3/3' else 'config'
        app.layout.setTitle t titleKey
        @display new ConfigView()

    display: (view) ->
        app.layout.transitionTo view

    forceRefresh: ->
        col = app.layout.currentView?.collection
        if col?.path is null then path = ''
        else if col?.path isnt undefined then path = col.path
        else return

        delete FolderCollection.cache[path]
        col.fetch()
