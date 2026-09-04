package include

import (
	"context"

	"github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter/inbound"
	"github.com/sagernet/sing-box/adapter/outbound"
	"github.com/sagernet/sing-box/dns"
	"github.com/sagernet/sing-box/dns/transport"
	"github.com/sagernet/sing-box/dns/transport/hosts"
	"github.com/sagernet/sing-box/dns/transport/local"
	"github.com/sagernet/sing-box/protocol/direct"
	"github.com/sagernet/sing-box/protocol/http"
	"github.com/sagernet/sing-box/protocol/mixed"
	"github.com/sagernet/sing-box/protocol/redirect"
	"github.com/sagernet/sing-box/protocol/socks"
)

func Context(ctx context.Context) context.Context {
	return box.Context(ctx, InboundRegistry(), OutboundRegistry(), DNSTransportRegistry())
}

func InboundRegistry() *inbound.Registry {
	registry := inbound.NewRegistry()

	redirect.RegisterRedirect(registry)
	redirect.RegisterTProxy(registry)
	direct.RegisterInbound(registry)

	socks.RegisterInbound(registry)
	http.RegisterInbound(registry)
	mixed.RegisterInbound(registry)

	registerQUICInbounds(registry)

	return registry
}

func OutboundRegistry() *outbound.Registry {
	registry := outbound.NewRegistry()

	direct.RegisterOutbound(registry)

	socks.RegisterOutbound(registry)
	http.RegisterOutbound(registry)

	registerQUICOutbounds(registry)

	return registry
}

func DNSTransportRegistry() *dns.TransportRegistry {
	registry := dns.NewTransportRegistry()

	transport.RegisterTCP(registry)
	transport.RegisterUDP(registry)
	hosts.RegisterTransport(registry)
	local.RegisterTransport(registry)

	registerQUICTransports(registry)

	return registry
}
