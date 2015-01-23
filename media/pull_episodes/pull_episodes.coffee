elasticsearch   = require "elasticsearch"
csv             = require "csv"
fs              = require "fs"
tz              = require "timezone"

argv = require('yargs')
    .demand(['show','start','end'])
    .describe
        start:      "Start Date"
        end:        "End Date"
        ep_start:   "Start Date for Episodes"
        ep_end:     "End Date for Episodes"
        zone:       "Timezone"
    .default
        start:      null
        end:        null
        ep_start:   null
        ep_end:     null
        zone:       "America/Los_Angeles"
    .argv

zone = tz(require("timezone/#{argv.zone}"))

es = new elasticsearch.Client host:"logstash.i.scprdev.org:9200" #, log:{type:"stdio",level:"trace"}

start_date  = zone(argv.start,argv.zone)
end_date    = zone(argv.end,argv.zone)

console.error "Stats: #{ start_date } - #{ end_date }"

#----------

class AllStats extends require("stream").Transform
    constructor: ->
        super objectMode:true

        @stats = []

        @first_date = null
        @last_date = null

    _transform: (obj,encoding,cb) ->
        @stats.push obj

        console.error "Stats for #{obj.key}: ", obj.stats

        @first_date = obj.stats.first_date if !@first_date || obj.stats.first_date < @first_date
        @last_date = obj.stats.last_date if !@last_date || obj.stats.last_date > @last_date

        cb()

    _flush: (cb) ->
        # loop through and emit each stats line, with all the dates from first_date to last_date
        keys = []
        d = @first_date

        loop
            keys.push zone(d,"%Y-%m-%d",argv.zone)
            d = tz(d,"+1 day")
            break if d > @last_date

        # first push a header row
        @push ["key"].concat(keys)

        for s in @stats
            values = [s.key]

            for k in keys
                values.push s.stats.days[k] || 0

            @push values

        cb()


#----------

class EpisodeStats extends require("stream").Transform
    constructor: ->
        super objectMode:true
        @stats = {}

        @first_date = null
        @last_date = null

    _transform: (obj,encoding,cb) ->
        #console.log "Transform got ", obj

        day = zone(obj.timestamp,"%Y-%m-%d",argv.zone)

        @first_date = obj.timestamp if !@first_date
        @last_date = obj.timestamp

        @stats[ day ] ||= 0
        @stats[ day ] += 1

        cb()

    _flush: (cb) ->
        # emit stats
        @push first_date:@first_date, last_date:@last_date, days:@stats

        cb()

#----------

class Deduplicator extends require("stream").Transform
    constructor: ->
        super objectMode:true
        @seen = {}

    _transform: (obj,encoding,cb) ->
        #console.log "dedup got ", obj

        if obj.uuid
            if @seen[obj.uuid]
                # uuid seen... pass...
            else
                @push obj
                @seen[obj.uuid] = true

        else
            # key off a hash of ip, request and agent
            key = new Buffer("#{obj.ip}--#{obj.request}--#{obj.agent}").toString("base64")

            if @seen[key]
                # when?
                if (obj.timestamp - @seen[key]) < 60*5*1000 # 5 minutes
                    # too recently... don't write a new entry
                else
                    # go ahead and write
                    @push obj
            else
                @push obj

            # either way, note the new timestamp
            @seen[key] = obj.timestamp

        cb()

    _flush: (cb) ->
        cb()

#----------

class EpisodePuller extends require("stream").Transform
    constructor: ->
        super objectMode:true

    #----------

    _indices: (ep_date) ->
        idxs = []

        # starting with ep_date or start_date (whichever is later), list each
        # day up to (and including) end_date

        start = if (start_date && start_date > ep_date) then start_date else ep_date
        end = if end_date then end_date else Number(new Date())

        ts = start

        loop
            idxs.push "logstash-#{tz(ts,"%Y.%m.%d")}"
            ts = tz(ts,"+1 day")
            break if ts > end

        return idxs

    #----------

    _transform: (ep,encoding,cb) ->
        # -- set up our pipeline -- #

        dedup = new Deduplicator
        stats = new EpisodeStats

        dedup.pipe(stats)

        stats.once "readable", =>
            @push key:ep.date, stats:stats.read()
            dedup.unpipe()
            stats.unpipe()
            stats.removeAllListeners()
            cb()

        # -- prepare our query -- #

        console.error "Processing #{ ep.date }"

        ep_date = zone(ep.date,argv.zone)

        body =
            query:
                filtered:
                    query:
                        match_all:{}
                    filter:
                        and:[
                            term:
                                "nginx_host.raw":"media.scpr.org"
                        ,
                            term:
                                "verb.raw":"GET"
                        ,
                            terms:
                                "response.raw":["200","206"]
                        ,
                            range:
                                bytes_sent:
                                    gte: 8193
                        ,
                            terms:
                                "request_path.raw":["/audio/#{ep.file}","/podcasts/#{ep.file}"]
                                _cache: false
                        ]
            sort: [ "@timestamp":"asc" ]
            size: 1000

        console.error "Searching for ", JSON.stringify(body)

        _writeResults = (results) =>
            for r in results
                dedup.write
                    timestamp:  tz(r._source["@timestamp"])
                    path:       r._source.request_path
                    agent:      r._source.agent
                    ip:         r._source.clientip
                    uuid:       r._source.quuid
                    via:        r._source.qvia
                    context:    r._source.qcontext
                    request:    r._source.request

        es.search index:@_indices(ep_date), body:body, type:"nginx", scroll:"25s", (err,results) ->
            if err
                console.error "ES ERROR: ", err
                return false

            total_results = results.hits.total
            remaining_results = total_results - 1000

            console.error "Got first 1000 of ", total_results, results.hits.hits.length, results._scroll_id.length

            _writeResults results.hits.hits

            if remaining_results > 0
                _remaining = (scroll_id,rcb) =>
                    if remaining_results <= 0
                        # we're done
                        return rcb()

                    # do our scroll query
                    es.scroll scroll:"25s", body:scroll_id, (err,results) ->
                        if err
                            console.error "Scroll error: #{err}"

                        #console.error "scroll: ", err, results
                        console.error "Scroll got ", results.hits.hits.length

                        if results.hits.hits.length == 0
                            # we'll assume we need to move on
                            return rcb()

                        remaining_results -= results.hits.hits.length

                        _writeResults results.hits.hits

                        _remaining results._scroll_id, rcb

                _remaining results._scroll_id, =>
                    console.error "Finished scrolling for #{ep.date}"
                    dedup.end()

            else
                console.error "No scrolling for #{ep.date}"
                dedup.end()

#----------

# -- open our episodes CSV -- #

ep_puller = new EpisodePuller
all_stats = new AllStats

csv_encoder = csv.stringify()

ep_puller.pipe(all_stats).pipe(csv_encoder).pipe(process.stdout)
all_stats.once "end", ->
    setTimeout ->
        process.exit()
    , 500

ep_parser = csv.parse {}, (err,data) ->
    for e in data
        ep_puller.write date:e[0], file:e[1], size:e[2]

    ep_puller.end()



