package P0302

import (
	"fmt"
	"sync/atomic"
)

type Stats struct {
	GetCount  int64
	PostCount int64
}

func (s *Stats) PlusGet() {
	atomic.AddInt64(&s.GetCount, 1)
}

func (s *Stats) PlusPost() {
	atomic.AddInt64(&s.PostCount, 1)
}

func (s *Stats) GetStr() string {
	get := atomic.LoadInt64(&s.GetCount)
	post := atomic.LoadInt64(&s.PostCount)

	return fmt.Sprintf("Get-request count = %d, Post-request count = %d", get, post)
}
