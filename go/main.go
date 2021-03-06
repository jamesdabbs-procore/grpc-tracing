package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"time"

	opentracing "github.com/opentracing/opentracing-go"
	"github.com/opentracing/opentracing-go/ext"
	pb "github.com/procore/example/example"
	jaegercfg "github.com/uber/jaeger-client-go/config"
	jaegerlog "github.com/uber/jaeger-client-go/log"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

type server struct {
}

func (c *server) Single(ctx context.Context, req *pb.Request) (*pb.Response, error) {
	meta, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil, errors.New("Failed to parse metadata")
	}

	spanCtx, err := opentracing.GlobalTracer().Extract(
		opentracing.HTTPHeaders,
		opentracing.HTTPHeadersCarrier(meta),
	)
	if err != nil {
		return nil, err
	}

	span, ctx := opentracing.StartSpanFromContext(ctx, "Single", ext.RPCServerOption(spanCtx))
	defer span.Finish()

	return handle(ctx, req), nil
}

func (c *server) Batch(srv pb.Example_BatchServer) error {
	ctx := srv.Context()

	meta, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return errors.New("Failed to parse metadata")
	}

	spanCtx, err := opentracing.GlobalTracer().Extract(
		opentracing.HTTPHeaders,
		opentracing.HTTPHeadersCarrier(meta),
	)
	if err != nil {
		return err
	}

	span, ctx := opentracing.StartSpanFromContext(ctx, "Batch", ext.RPCServerOption(spanCtx))
	defer span.Finish()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		req, err := srv.Recv()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			log.Printf("receive error %v", err)
			continue
		}

		res := handle(ctx, req)
		if err := srv.Send(res); err != nil {
			log.Printf("send error %v", err)
		}
	}
}

func handle(ctx context.Context, req *pb.Request) *pb.Response {
	span, _ := opentracing.StartSpanFromContext(ctx, "handle")
	defer span.Finish()

	time.Sleep(10 * time.Millisecond)

	runes := []rune(req.Message)
	for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
		runes[i], runes[j] = runes[j], runes[i]
	}

	return &pb.Response{
		Message: string(runes),
	}
}

const (
	port = ":5555"
)

func main() {
	cfg := jaegercfg.Configuration{
		Sampler: &jaegercfg.SamplerConfig{
			Type:  "const",
			Param: 1,
		},
		Reporter: &jaegercfg.ReporterConfig{
			CollectorEndpoint: "http://jaeger:14268/api/traces",
			LogSpans:          false,
		},
	}

	closer, err := cfg.InitGlobalTracer(
		"example/server/go",
		jaegercfg.Logger(jaegerlog.StdLogger),
	)
	defer closer.Close()
	if err != nil {
		log.Fatalf("failed to start tracing: %v", err)
	}

	lis, err := net.Listen("tcp", port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()
	impl := &server{}

	pb.RegisterExampleServer(s, impl)

	fmt.Printf("serving on %v\n", port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
