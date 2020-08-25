A demo of cross-language (Ruby => Go) gRPC tracing support.

To run

    docker-compose up -d go-server ruby-server jaeger
    docker-compose run ruby-client

and then inspect the results using Jaeger's web UI (http://localhost:16686).

The `ruby-client` makes several requests to the `server-proxy` which load balances between a `ruby-server` and a `go-server`. This should produce traces like:

