package provider

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"

	"github.com/metacubex/mihomo/common/structure"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/common/yaml"
	"github.com/metacubex/mihomo/component/resource"
	C "github.com/metacubex/mihomo/constant"
)

const MaxSnapshotBytes int64 = 64 << 20

// ReadProxyMappings 为脚本和聚合读取指定配置的节点，不依赖当前活动 profile。
func ReadProxyMappings(ctx context.Context, mapping map[string]any) ([]map[string]any, error) {
	schema := &proxyProviderSchema{}
	if err := structure.NewDecoder(structure.Option{TagName: "provider", WeaklyTypedInput: true}).Decode(mapping, schema); err != nil {
		return nil, errors.New("invalid provider options")
	}
	parser, err := newProxiesParser(schema.Filter, schema.ExcludeFilter, schema.ExcludeType, schema.DialerProxy, schema.Override, schema.AgeSecretKey,
		func(node map[string]any) (map[string]any, error) { return node, nil })
	if err != nil {
		return nil, errors.New("invalid provider filter or override")
	}
	limit := MaxSnapshotBytes
	if schema.SizeLimit > 0 && schema.SizeLimit < limit {
		limit = schema.SizeLimit
	}
	parse := func(buf []byte) ([]map[string]any, error) {
		if int64(len(buf)) > limit {
			return nil, errors.New("provider exceeds size limit")
		}
		nodes, err := parser(buf)
		if err != nil {
			return nil, errors.New("invalid provider nodes or override")
		}
		return nodes, nil
	}
	read := func(path string) ([]map[string]any, error) {
		file, err := os.Open(path)
		if err != nil {
			return nil, err
		}
		defer file.Close()
		buf, err := io.ReadAll(io.LimitReader(file, limit+1))
		if err != nil {
			return nil, err
		}
		return parse(buf)
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	switch schema.Type {
	case "inline":
		buf, err := yaml.Marshal(ProxySchema{Proxies: schema.Payload})
		if err != nil {
			return nil, errors.New("invalid inline provider")
		}
		return parse(buf)
	case "file":
		path := C.Path.Resolve(schema.Path)
		if !C.Path.IsSafePath(path) {
			return nil, errors.New("provider path outside config directory")
		}
		nodes, err := read(path)
		if err != nil {
			return nil, errors.New("cannot read file provider")
		}
		return nodes, nil
	case "http":
		// URL 和请求头共同确定缓存，避免同名 provider 串用另一个订阅的节点。
		identity, _ := json.Marshal([]any{schema.URL, schema.Header})
		path := C.Path.GetPathByHash("script-providers", string(identity))
		vehicle := resource.NewHTTPVehicle(schema.URL, path, schema.Proxy, schema.Header, resource.DefaultHttpTimeout, limit+1)
		buf, _, err := vehicle.Read(ctx, utils.HashType{})
		if err == nil {
			nodes, parseErr := parse(buf)
			if parseErr != nil {
				return nil, parseErr
			}
			// 只写验证过的缓存，供离线重新应用配置使用。
			_ = vehicle.Write(buf)
			return nodes, nil
		}
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		if nodes, cachedErr := read(path); cachedErr == nil {
			return nodes, nil
		}
		return nil, errors.New("cannot download provider nodes")
	default:
		return nil, errors.New("unsupported provider type")
	}
}
