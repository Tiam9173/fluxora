package route

import (
	"testing"

	"github.com/metacubex/http"
	"github.com/metacubex/http/httptest"
)

func TestControllerAuthentication(t *testing.T) {
	for _, path := range []string{"/version", "/debug/pprof/"} {
		for _, tc := range []struct {
			name, secret, header string
			status               int
		}{
			{"no secret", "", "", http.StatusOK},
			{"missing token", "local-test", "", http.StatusUnauthorized},
			{"wrong token", "local-test", "Bearer wrong", http.StatusUnauthorized},
			{"valid token", "local-test", "Bearer local-test", http.StatusOK},
		} {
			t.Run(path+"/"+tc.name, func(t *testing.T) {
				req := httptest.NewRequest(http.MethodGet, path, nil)
				req.Header.Set("Authorization", tc.header)
				response := httptest.NewRecorder()
				router(true, tc.secret, "", Cors{}).ServeHTTP(response, req)
				if response.Code != tc.status {
					t.Fatalf("status = %d, want %d", response.Code, tc.status)
				}
			})
		}
	}
}
