BaseView = require '../lib/base_view'

log = require('../lib/persistent_log')
    prefix: "FolderLineView"
    date: true

module.exports = class FolderLineView extends BaseView



    tagName: 'a'
    template: require '../templates/folder_line'
    events:
        'tap .item-content': 'onClick'
        'tap .item-options .download': 'addToCache'
        'tap .item-options .uncache': 'removeFromCache'

    className: 'item item-icon-left item-icon-right item-complex'

    initialize: =>
        @listenTo @model, 'change', @render

    getRenderData: ->
        _.extend super, isFolder: @model.isFolder()

    afterRender: =>
        @$el[0].dataset.folderid = @model.get('_id')
        if @model.isDeviceFolder
            @$('.ion-folder').css color: '#34a6ff'

    setCacheIcon: (klass) =>
        icon = @$('.cache-indicator')
        icon.removeClass('ion-warning ion-ios7-cloud-download-outline')
        icon.removeClass('ion-ios7-download-outline ion-looping')
        icon.append klass
        @parent?.ionicView?.clearDragEffects()

    displayProgress: =>
        @downloading = true
        @setCacheIcon '<img src="img/spinner-grey.svg"></img>'
        @progresscontainer = $('<div class="item-progress"></div>')
            .append @progressbar = $('<div class="item-progress-bar"></div>')

        @progresscontainer.appendTo @$el

    hideProgress: (err, incache) =>
        @downloading = false
        if err then alert err

        incache = app.replicator.fileInFileSystem @model.attributes
        version = app.replicator.fileVersion @model.attributes

        if incache? and incache isnt @model.get 'incache'
            @model.set {incache}

        if version? and version isnt @model.get 'version'
            @model.set {version}

        @progresscontainer?.remove()
        @render()

    updateProgress: (done, total) =>
        @progressbar?.css 'width', (100 * done / total) + '%'

    getOnDownloadedCallback: (callback) ->
        callback = callback or ->
        return (err, url) =>
            @hideProgress()

            if err
                log.error err
                return alert t(err.message)
            @model.set incache: true
            @model.set version: app.replicator.fileVersion @model.attributes
            callback(err, url)

    onClick: (event) =>
        # ignore .cache-indicator click
        # they are handled by folder.coffee#displaySlider
        return true if $(event.target).closest('.cache-indicator').length
        return true if @downloading

        if @model.isFolder()
            path = @model.get('path') + '/' + @model.get('name')
            app.router.navigate "#folder#{path}", trigger: true
            return true

        # else, the model is a file, we get its binary and open it
        @displayProgress()
        app.replicator.getBinary @model.attributes, @updateProgress, \
          @getOnDownloadedCallback (err, url) ->
              # let android open the file
              app.init.trigger 'openFile'
              # app.backFromOpen = true
              ExternalFileUtil.openWith url, '', undefined,
                (success) -> , # do nothing
                (err) ->
                    if 0 is err?.indexOf 'No Activity found'
                        err = t 'no activity found'
                    alert err.message
                    log.error err

    addToCache: =>
        return true if @downloading

        @displayProgress()
        if @model.isFolder()
            app.replicator.getBinaryFolder @model.attributes, @updateProgress,\
                @getOnDownloadedCallback()
        else
            app.replicator.getBinary @model.attributes, @updateProgress, \
                @getOnDownloadedCallback()

    removeFromCache: =>
        return true if @downloading

        @displayProgress()
        onremoved = (err) =>
            @hideProgress()
            return alert err if err
            @model.set incache: false

        if @model.isFolder()
            app.replicator.removeLocalFolder @model.attributes, onremoved
        else
            app.replicator.removeLocal @model.attributes, onremoved

    mimeClasses:
        'application/octet-stream'      : 'type-file'
        'application/x-binary'          : 'type-binary'
        'text/plain'                    : 'type-text'
        'text/richtext'                 : 'type-text'
        'application/x-rtf'             : 'type-text'
        'application/rtf'               : 'type-text'
        'application/msword'            : 'type-text'
        'application/x-iwork-pages-sffpages' : 'type-text'
        'application/mspowerpoint'      : 'type-presentation'
        'application/vnd.ms-powerpoint' : 'type-presentation'
        'application/x-mspowerpoint'    : 'type-presentation'
        'application/x-iwork-keynote-sffkey' : 'type-presentation'
        'application/excel'             : 'type-spreadsheet'
        'application/x-excel'           : 'type-spreadsheet'
        'aaplication/vnd.ms-excel'      : 'type-spreadsheet'
        'application/x-msexcel'         : 'type-spreadsheet'
        'application/x-iwork-numbers-sffnumbers' : 'type-spreadsheet'
        'application/pdf'               : 'type-pdf'
        'text/html'                     : 'type-code'
        'text/asp'                      : 'type-code'
        'text/css'                      : 'type-code'
        'application/x-javascript'      : 'type-code'
        'application/x-lisp'            : 'type-code'
        'application/xml'               : 'type-code'
        'text/xml'                      : 'type-code'
        'application/x-sh'              : 'type-code'
        'text/x-script.python'          : 'type-code'
        'application/x-bytecode.python' : 'type-code'
        'text/x-java-source'            : 'type-code'
        'application/postscript'        : 'type-image'
        'image/gif'                     : 'type-image'
        'image/jpg'                     : 'type-image'
        'image/jpeg'                    : 'type-image'
        'image/pjpeg'                   : 'type-image'
        'image/x-pict'                  : 'type-image'
        'image/pict'                    : 'type-image'
        'image/png'                     : 'type-image'
        'image/x-pcx'                   : 'type-image'
        'image/x-portable-pixmap'       : 'type-image'
        'image/x-tiff'                  : 'type-image'
        'image/tiff'                    : 'type-image'
        'audio/aiff'                    : 'type-audio'
        'audio/x-aiff'                  : 'type-audio'
        'audio/midi'                    : 'type-audio'
        'audio/x-midi'                  : 'type-audio'
        'audio/x-mid'                   : 'type-audio'
        'audio/mpeg'                    : 'type-audio'
        'audio/x-mpeg'                  : 'type-audio'
        'audio/mpeg3'                   : 'type-audio'
        'audio/x-mpeg3'                 : 'type-audio'
        'audio/wav'                     : 'type-audio'
        'audio/x-wav'                   : 'type-audio'
        'video/avi'                     : 'type-video'
        'video/mpeg'                    : 'type-video'
        'video/mp4'                     : 'type-video'
        'application/zip'               : 'type-archive'
        'multipart/x-zip'               : 'type-archive'
        'multipart/x-zip'               : 'type-archive'
        'application/x-bzip'            : 'type-archive'
        'application/x-bzip2'           : 'type-archive'
        'application/x-gzip'            : 'type-archive'
        'application/x-compress'        : 'type-archive'
        'application/x-compressed'      : 'type-archive'
        'application/x-zip-compressed'  : 'type-archive'
        'application/x-apple-diskimage' : 'type-archive'
        'multipart/x-gzip'              : 'type-archive'
