elasticsearch   = require "elasticsearch"
csv             = require "csv"
fs              = require "fs"
tz              = require "timezone"
debug           = require("debug")("scpr")

argv = require('yargs')
    .demand([])
    .describe
        zone:       "Timezone"
        verbose:    "Show debugging logs"
    .default
        verbose:    false
        zone:       "America/Los_Angeles"
    .argv

if argv.verbose
    (require "debug").enable("scpr")
    debug = require("debug")("scpr")

zone = tz(require("timezone/#{argv.zone}"))

es = new elasticsearch.Client host:"es-scpr-es.service.consul:9200"
idx = "scprv4_production-articles-all"

#----------

class BylinePuller extends require("stream").Transform
    constructor: ->
        super objectMode:true

        @push ["Publish Date","Title","URL","Reporter"]

    _transform: (obj,encoding,cb) ->
        debug "Running #{obj.name}"

        body =
            query:
                filtered:
                    query:
                        match_phrase:
                            "attributions.name": obj.name
                    filter:
                        and: [
                            term: { published:true }
                        ,
                            range:
                                public_datetime:
                                    gte:    tz(obj.start,"%Y-%m-%dT%H:%M")
                                    lt:     tz(obj.end,"%Y-%m-%dT%H:%M")
                        ]
            size: 500

        debug "Searching for: ", JSON.stringify(body)

        es.search index:idx, body:body, (err,results) =>
            throw err if err

            debug "Got #{ results.hits.total } results for #{ obj.name }"
            for c in results.hits.hits
                result =
                    name:           obj.name
                    title:          c._source.title
                    published_at:   zone(c._source.public_datetime,"%Y-%m-%d %H:%M",argv.zone),
                    url:            "http://www.scpr.org"+c._source.public_path

                @push [result.published_at,result.title,result.url,result.name]

            cb()

#----------

byline_puller = new BylinePuller

csv_encoder = csv.stringify()

byline_puller.pipe(csv_encoder).pipe(process.stdout)

csv_encoder.on "finish", =>
    process.exit()

name_parser = csv.parse {}, (err,data) ->
    for person in data
        byline_puller.write name:person[0], start:zone(person[1],argv.zone), end:zone(person[2],"+1 day",argv.zone)

    byline_puller.end()

process.stdin.pipe(name_parser)