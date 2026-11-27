package resource

import (
	"context"
	"errors"
	"path/filepath"
	"sync"
	"testing"

	"github.com/metacubex/mihomo/common/utils"
	P "github.com/metacubex/mihomo/constant/provider"
)

type delayedVehicle struct {
	refreshVehicle
	started, release chan struct{}
	wrote            bool
}

func (v *delayedVehicle) Read(_ context.Context, _ utils.HashType) ([]byte, utils.HashType, error) {
	close(v.started)
	<-v.release
	data := []byte("old")
	return data, utils.MakeHash(data), nil
}

func (v *delayedVehicle) Write([]byte) error {
	v.wrote = true
	return nil
}

func TestClosedFetcherDropsLateRefresh(t *testing.T) {
	vehicle := &delayedVehicle{started: make(chan struct{}), release: make(chan struct{})}
	f := NewFetcher("old", 0, vehicle, nil, func(buf []byte) ([]byte, error) {
		return buf, nil
	}, nil)
	errc := make(chan error, 1)
	go func() {
		_, _, err := f.Update()
		errc <- err
	}()
	<-vehicle.started
	_ = f.Close()
	close(vehicle.release)
	if err := <-errc; !errors.Is(err, context.Canceled) || vehicle.wrote {
		t.Fatalf("retired refresh: err = %v, cache written = %v", err, vehicle.wrote)
	}
}

type refreshVehicle struct {
	P.Vehicle
	path string
}

func (v refreshVehicle) Path() string        { return v.path }
func (v refreshVehicle) Type() P.VehicleType { return P.HTTP }
func (v refreshVehicle) Write([]byte) error  { return nil }
func (v refreshVehicle) Read(_ context.Context, oldHash utils.HashType) ([]byte, utils.HashType, error) {
	data := []byte("remote")
	hash := utils.MakeHash(data)
	if hash.Equal(oldHash) {
		return nil, hash, nil
	}
	return data, hash, nil
}

func TestFetcherConcurrentRefresh(t *testing.T) {
	vehicle := refreshVehicle{path: filepath.Join(t.TempDir(), "cache")}
	f := NewFetcher("local", 0, vehicle, nil, func(data []byte) (string, error) { return string(data), nil }, nil)
	t.Cleanup(func() { _ = f.Close() })
	var writers sync.WaitGroup
	writers.Add(1)
	begin := make(chan struct{})
	go func() {
		defer writers.Done()
		<-begin
		for i := 0; i < 300; i++ {
			if _, _, err := f.Update(); err != nil {
				t.Error(err)
			}
		}
	}()
	close(begin)
	defer writers.Wait()
	for i := 0; i < 300; i++ {
		if _, _, err := f.SideUpdate([]byte{byte(i % 2)}); err != nil {
			t.Fatal(err)
		}
	}
}
