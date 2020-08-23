A demo of cross-language (Ruby => Go) gRPC tracing support.

To run

    docker-compose up -d go-server ruby-server jaeger
    docker-compose run ruby-client

and then inspect the results using Jaeger's web UI (http://localhost:16686).

The `ruby-client` makes several requests to the `server-proxy` which load balances between a `ruby-server` and a `go-server`. This should produce traces like:

![Traces](https://user-images.githubusercontent.com/40446776/91220776-84df4700-e6d1-11ea-8374-787ff039747c.png)
![Trace Detail](https://user-images.githubusercontent.com/40446776/91220780-86107400-e6d1-11ea-8e19-a90c2b186412.png)
