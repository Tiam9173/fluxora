package main

import (
	"encoding/json"
	"testing"
)

func TestLogHistoryKeepsNewestEntriesInOrder(t *testing.T) {
	handleClearLogs()
	t.Cleanup(func() { handleClearLogs() })
	for i := 0; i < 2*maxLogHistory+3; i++ {
		recordLogHistory(logEntry{Time: int64(i)})
	}

	var entries []logEntry
	if err := json.Unmarshal([]byte(handleGetLogs()), &entries); err != nil {
		t.Fatal(err)
	}
	if len(entries) != maxLogHistory {
		t.Fatalf("got %d entries, want %d", len(entries), maxLogHistory)
	}
	for i, entry := range entries {
		if want := int64(maxLogHistory + 3 + i); entry.Time != want {
			t.Fatalf("entry %d: got %d, want %d", i, entry.Time, want)
		}
	}
	handleClearLogs()
	if got := handleGetLogs(); got != "[]" {
		t.Fatalf("history after clear: %s", got)
	}
	recordLogHistory(logEntry{Time: 42})
	if err := json.Unmarshal([]byte(handleGetLogs()), &entries); err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].Time != 42 {
		t.Fatalf("history after clear and append: %+v", entries)
	}
}

func BenchmarkRecordFullLogHistory(b *testing.B) {
	handleClearLogs()
	b.Cleanup(func() { handleClearLogs() })
	entry := logEntry{Time: 42}
	for i := 0; i < maxLogHistory; i++ {
		recordLogHistory(entry)
	}
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		recordLogHistory(entry)
	}
}
