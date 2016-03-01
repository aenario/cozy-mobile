AndroidAccount = require "../fromDevice/android_account"
AndroidCalendarHandler = require "../../lib/android_calendar_handler"
CozyToAndroidEvent = require "../transformer/cozy_to_android_event"
log = require('../../lib/persistent_log')
    prefix: "ChangeEventHandler"
    date: true

###*
 * ChangeEventHandler Can create, update or delete an event on your device
 *
 * @class ChangeEventHandler
###
module.exports = class ChangeEventHandler

    constructor: (@calendarSync) ->
        @androidCalendarHandler = new AndroidCalendarHandler()
        @cozyToAndroidEvent = new CozyToAndroidEvent()
        @calendarSync ?= navigator.calendarsync

    dispatch: (cozyEvent, callback) ->
        log.info "dispatch"
        @calendarSync.eventBySyncId cozyEvent._id, (err, androidEvents) =>
            if androidEvents.length > 0
                androidEvent = androidEvents[0]
                if cozyEvent._deleted
                    @_delete cozyEvent, androidEvent, callback
                else
                    @_update cozyEvent, androidEvent, callback
            else
                # event may have already been deleted from device
                # or event never been created
                @_create cozyEvent, callback unless cozyEvent._deleted


    _create: (cozyEvent, callback) ->
        log.info "_create"

        calendarName = cozyEvent.tags[0]
        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return callback err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar
            @calendarSync.addEvent androidEvent, \
                    AndroidAccount.ACCOUNT, callback


    _update: (cozyEvent, androidEvent, callback) ->
        log.info "_update"

        calendarName = cozyEvent.tags[0]
        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return callback err if err

            # delete calendar in background
            if calendar._id isnt androidEvent.calendar_id
                @androidCalendarHandler.deleteIfEmptyById \
                        androidEvent.calendar_id, (err) ->
                    log.error err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar, \
                    androidEvent
            @calendarSync.updateEvent androidEvent, \
                    AndroidAccount.ACCOUNT, callback


    _delete: (cozyEvent, androidEvent, callback) ->
        log.info "_delete"

        @calendarSync.deleteEvent androidEvent, \
                AndroidAccount.ACCOUNT, (err, deletedCount) =>
            log.error err if err

            # delete calendar in background
            @androidCalendarHandler.deleteIfEmptyById \
                    androidEvent.calendar_id, (err) ->
                log.error err if err

            callback()
