exports.config =

    # See docs at http://brunch.readthedocs.org/en/latest/config.html.

    paths:
        public:  '../www'
        test: 'tests'

    plugins:
        coffeelint:
            options:
                indentation: value: 4, level: 'error'

    conventions:
        vendor:  /(vendor)|(tests)(\/|\\)/ # do not wrap tests in modules

    files:
        javascripts:
            joinTo:
                'javascripts/app.js': /^app/
                'javascripts/vendor.js': /^vendor/
                '../tests/tests.js': /^test.*\.coffee/
            order:
                # Files in `vendor` directories are compiled before other files
                # even if they aren't specified in order.
                before: [
                    'vendor/scripts/jquery-1.9.1.js'
                    'vendor/scripts/underscore-1.4.4.js'
                    'vendor/scripts/backbone-1.0.0.js'
                ]

        stylesheets:
            joinTo: 'stylesheets/app.css'
            order:
                before: []
                after: []

        templates:
            defaultExtension: 'jade'
            joinTo: 'javascripts/app.js'
