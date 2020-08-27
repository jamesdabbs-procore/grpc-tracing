A demo of cross-language (Ruby => Go) gRPC tracing support.

To run

    docker-compose up -d --scale ruby-client=0
    docker-compose run ruby-client <n>

and then inspect the results using Jaeger's web UI (http://localhost:16686).

Requests flow

`ruby-client`
=> `client-proxy`
=> `server-proxy`
=> round robin between `go-server` & `ruby-server`

![Traces](https://user-images.githubusercontent.com/40446776/91220776-84df4700-e6d1-11ea-8374-787ff039747c.png)
![Trace Detail](https://user-images.githubusercontent.com/40446776/91220780-86107400-e6d1-11ea-8e19-a90c2b186412.png)

`localhost`-exposed ports

* 7001  - client-proxy envoy admin
* 8001  - server-proxy envoy admin
* 16686 - jaeger web

See `docker-compose.yml` for more details
