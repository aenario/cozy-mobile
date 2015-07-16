DeviceStatus = require '../lib/device_status'
Utils = require './utils'
fs = require './filesystem'
request = require '../lib/request'


# This files contains all replicator functions liked to backup
# use the ImagesBrowser cordova plugin to fetch images & contacts
# from phone.
# Set the inBackup attribute to true while a backup is in progress
# Set the backup_step attribute with value in
# [contacts_scan, pictures_sync, contacts_sync]
# For each step, hint of progress are in backup_step_done and backup_step_total

module.exports =

    # wrapper around _backup to maintain the state of inBackup
    backup: (options, callback = ->) ->
        return callback null if @get 'inBackup'

        options = options or { force: false }

        @set 'inBackup', true
        @set 'backup_step', null
        @stopRealtime()
        @_backup options.force, (err) =>
            @set 'backup_step', null
            @set 'inBackup', false
            @startRealtime() unless options.background
            return callback err if err
            @config.save lastBackup: new Date().toString(), (err) =>
                callback null


    _backup: (force, callback) ->
        DeviceStatus.checkReadyForSync true, (err, ready, msg) =>
            console.log "SYNC STATUS", err, ready, msg
            return callback err if err
            return callback new Error(msg) unless ready
            console.log "WE ARE READY FOR SYNC"

            async.series [
                (cb) => @syncPictures force, cb
                (cb) =>
                    status = DeviceStatus.getStatus()
                    if status.readyForSync
                        @syncCache cb
                    else
                        cb status.readyForSyncMsg

                (cb) =>
                    status = DeviceStatus.getStatus()
                    if status.readyForSync
                        @syncContacts cb
                    else
                        cb status.readyForSyncMsg

            ], (err) ->
                console.log "Backup done."
                callback err


    syncPictures: (force, callback) ->
        return callback null unless @config.get 'syncImages'

        console.log "SYNC PICTURES"
        @set 'backup_step', 'pictures_scan'
        @set 'backup_step_done', null
        async.series [
            @ensureDeviceFolder.bind this
            ImagesBrowser.getImagesList
            (callback) => @photosDB.query 'PhotosByLocalId', {}, callback
            (cb) => @db.query 'FilesAndFolder',
                {
                    startkey: ['/' + t 'photos']
                    endkey: ['/' + t('photos'), {}]
                } , cb
        ], (err, results) =>
            return callback err if err
            [device, images, rows: dbImages, dbPictures] = results

            dbImages = dbImages.map (row) -> row.key
            # We pick up the filename from the key to improve speed :
            # query without include_doc are 100x faster
            dbPictures = dbPictures.rows.map (row) -> row.key[1]?.slice 2

            myDownloadFolder = @downloads.toURL().replace 'file://', ''

            toUpload = []

            # Filter images : keep only the ones from Camera
            # TODO: Android Specific !
            images = images.filter (path) -> path.indexOf('/DCIM/') != -1

            if images.length is 0
                return callback new Error 'no images in DCIM'

            # step 1 scan all images, find the new ones
            async.eachSeries images, (path, cb) =>
                #Check if pictures is in dbImages
                if path in dbImages
                    cb()
                else
                    # Check if pictures is already present (old installation)
                    fs.getFileFromPath path, (err, file) =>
                        # We test only on filename, case-insensitive
                        if file.name?.toLowerCase() in dbPictures
                            # Add photo in local database
                            @createPhoto path
                        else
                            # Create file
                            toUpload.push path

                        DeviceStatus.checkReadyForSync (err, ready, msg) ->
                            return cb err if err
                            return cb new Error msg unless ready

                            setTimeout cb, 1 # don't freeze UI


            , =>
                # step 2 upload one by one
                console.log "SYNC IMAGES : #{images.length} #{toUpload.length}"
                processed = 0
                @set 'backup_step', 'pictures_sync'
                @set 'backup_step_total', toUpload.length
                async.eachSeries toUpload, (path, cb) =>
                    @set 'backup_step_done', processed++
                    console.log "UPLOADING #{path}"
                    @uploadPicture path, device, (err) =>
                        console.log "ERROR #{path} #{err}" if err
                        if DeviceStatus.readyForSync
                            setTimeout cb, 1  # don't freeze UI.
                        else
                            # stop uploading if leaves wifi and ...
                            cb DeviceStatus.readyForSyncMsg

                , callback

    uploadPicture: (path, device, callback) ->
        fs.getFileFromPath path, (err, file) =>
            return callback err if err

            fs.contentFromFile file, (err, content) =>
                return callback err if err

                @createBinary content, file.type, (err, bin) =>
                    return callback err if err

                    @createFile file, path, bin, device, (err, res) =>
                        return callback err if err

                        @createPhoto path, callback


    createBinary: (blob, mime, callback) ->
        @config.remote.post docType: 'Binary', (err, doc) =>
            return callback err if err
            return callback new Error('cant create binary') unless doc.ok

            @config.remote.putAttachment doc.id, 'file', doc.rev, blob, mime, (err, doc) =>
                return callback err if err
                return callback new Error('cant attach') unless doc.ok
                callback null, doc

    createFile: (cordovaFile, localPath, binaryDoc, device, callback) ->
        dbFile =
            docType          : 'File'
            localPath        : localPath
            name             : cordovaFile.name
            path             : "/" + t('photos')
            class            : @fileClassFromMime cordovaFile.type
            lastModification : new Date(cordovaFile.lastModified).toISOString()
            creationDate     : new Date(cordovaFile.lastModified).toISOString()
            size             : cordovaFile.size
            tags             : ['from-' + @config.get 'deviceName']
            binary: file:
                id: binaryDoc.id
                rev: binaryDoc.rev

        @config.remote.post dbFile, callback

    createPhoto: (localPath, callback) ->
        dbPhoto =
            docType : 'Photo'
            localId: localPath
        @photosDB.post dbPhoto, callback

    fileClassFromMime: (type) ->
        return switch type.split('/')[0]
            when 'image' then "image"
            when 'audio' then "music"
            when 'video' then "video"
            when 'text', 'application' then "document"
            else "file"

    ensureDeviceFolder: (callback) ->
        findDevice = (id, callback) =>
            @db.get id, (err, res) ->
                if not err?
                    callback()
                else
                    findDevice id, callback

        createNew = () =>
            console.log "MAKING ONE"
            # no device folder, lets make it
            folder =
                docType          : 'Folder'
                name             : t 'photos'
                path             : ''
                lastModification : new Date().toISOString()
                creationDate     : new Date().toISOString()
                tags             : []
            options =
                key: ['', "1_#{folder.name.toLowerCase()}"]
            @config.remote.post folder, (err, res) =>
                app.replicator.startRealtime()
                # Wait to receive folder in local database
                findDevice res.id, () ->
                    return callback err if err
                    callback null, folder

        @db.query 'FilesAndFolder', key: ['', "1_#{t('photos').toLowerCase()}"], (err, results) =>
            return callback err if err
            if results.rows.length > 0
                device = results.rows[0]
                console.log "DEVICE FOLDER EXISTS"
                return callback null, device
            else
                # TODO : relies on byFullPath folder view of cozy-file !
                query = '/_design/folder/_view/byfullpath/?' +
                    "key=\"/#{t('photos')}\""

                request.get @config.makeUrl(query), (err, res, body) ->
                    return callback err if err
                    if body?.rows?.length is 0
                        createNew()
                    else
                        # already exist remote, but not locally...
                        callback new Error 'photo folder not replicated yet'

