// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package dataset

import (
	"container/heap"
	"context"
	"sync"

	"github.com/apache/arrow-go/v18/arrow"
)

type TaggedRecord struct {
	RecordBatch arrow.Record
	Fragment    Fragment
	Err         error
}

type Enumerated[T any] struct {
	Value T
	Index int
	Last  bool
}

type EnumeratedRecord struct {
	RecordBatch Enumerated[arrow.Record]
	Fragment    Enumerated[Fragment]
	Err         error
}

type Scanner struct {
	options *ScanOptions
	dataset Dataset
}

type pqueue[T any] struct {
	queue []*T

	compare func(a, b *T) bool
}

func (pq *pqueue[T]) Len() int           { return len(pq.queue) }
func (pq *pqueue[T]) Less(i, j int) bool { return pq.compare(pq.queue[i], pq.queue[j]) }
func (pq *pqueue[T]) Swap(i, j int) {
	pq.queue[i], pq.queue[j] = pq.queue[j], pq.queue[i]
}

func (pq *pqueue[T]) Push(x any) {
	pq.queue = append(pq.queue, x.(*T))
}

func (pq *pqueue[T]) Pop() any {
	old := pq.queue
	n := len(old)

	item := old[n-1]
	old[n-1] = nil
	pq.queue = old[0 : n-1]
	return item
}

func makeSequencingChan[T any](bufferSize uint, source <-chan T, comesAfter, isNext func(a, b *T) bool, initial T) <-chan T {
	pq := pqueue[T]{queue: make([]*T, 0), compare: comesAfter}
	heap.Init(&pq)
	previous := &initial
	out := make(chan T, bufferSize)
	go func() {
		defer close(out)

		for val := range source {
			heap.Push(&pq, &val)

			for pq.Len() > 0 && isNext(previous, pq.queue[0]) {
				previous = heap.Pop(&pq).(*T)
				out <- *previous
			}
		}
	}()
	return out
}

func makeMappedChan[In, Out any](src <-chan In, fn func(In) Out) <-chan Out {
	output := make(chan Out, 10)
	go func() {
		defer close(output)
		for in := range src {
			output <- fn(in)
		}
	}()
	return output
}

func NewScanner(opts *ScanOptions, dataset Dataset) *Scanner {
	opts.Dataset = dataset

	return &Scanner{options: opts, dataset: dataset}
}

func NewScannerFromFragment(schema *arrow.Schema, fragment Fragment, opts *ScanOptions) *Scanner {
	ds := &fragmentDataset{schema: schema, fragments: []Fragment{fragment}}
	return NewScanner(opts, ds)
}

func (s *Scanner) ScanBatches(ctx context.Context) (<-chan TaggedRecord, error) {
	fragItr, err := s.dataset.GetFragments()
	if err != nil {
		return nil, err
	}

	frags := make(chan Enumerated[Fragment], s.options.FragmentReadahead)
	go func() {
		defer close(frags)

		var (
			i    = 0
			next = Enumerated[Fragment]{}
		)

		for {
			f := fragItr()
			if f == nil {
				if next.Value != nil {
					next.Last = true
					frags <- next
				}
				return
			}

			next = Enumerated[Fragment]{
				Value: f,
				Index: i,
			}
			i++
		}
	}()

	outputCh := make(chan EnumeratedRecord, s.options.FormatOptions.ChannelBufferSize())

	var wg sync.WaitGroup
	wg.Add(int(s.options.FragmentReadahead))
	for i := 0; i < int(s.options.FragmentReadahead); i++ {
		go func() {
			defer wg.Done()
			for {
				select {
				case <-ctx.Done():
					return
				case enumFrag, ok := <-frags:
					if !ok {
						return
					}

					gen, err := enumFrag.Value.ScanBatches(ctx, s.options)
					if err != nil {
						outputCh <- EnumeratedRecord{
							Fragment: enumFrag,
							Err:      err,
						}
						return
					}

					var (
						idx       = 0
						outRecord EnumeratedRecord
					)

					for {
						select {
						case <-ctx.Done():
							return
						case rec, ok := <-gen:
							if !ok {
								if outRecord.RecordBatch.Value != nil {
									outRecord.RecordBatch.Last = true
									outputCh <- outRecord
								}
							}

							if outRecord.RecordBatch.Value != nil {
								outputCh <- outRecord
							}

							if rec.Err != nil {
								outputCh <- EnumeratedRecord{
									RecordBatch: Enumerated[arrow.Record]{
										Index: idx,
										Last:  true,
									},
									Fragment: enumFrag,
									Err:      rec.Err,
								}
								break
							}

							outRecord = EnumeratedRecord{
								RecordBatch: Enumerated[arrow.Record]{
									Value: rec.Record,
									Index: idx,
								},
								Fragment: enumFrag,
								Err:      rec.Err,
							}
						}
					}
				}
			}
		}()
	}

	go func() {
		defer close(outputCh)
		wg.Wait()
	}()

	isBeforeAny := func(batch EnumeratedRecord) bool {
		return batch.Fragment.Index < 0
	}

	return makeMappedChan(makeSequencingChan(uint(s.options.FormatOptions.ChannelBufferSize()), outputCh, func(left, right *EnumeratedRecord) bool {
		switch {
		case isBeforeAny(*left):
			return true
		case isBeforeAny(*right):
			return false
		case left.Fragment.Index == right.Fragment.Index:
			return left.RecordBatch.Index < right.RecordBatch.Index
		default:
			return left.Fragment.Index < right.Fragment.Index
		}
	}, func(prev, next *EnumeratedRecord) bool {
		switch {
		case isBeforeAny(*prev):
			return next.Fragment.Index == 0 && next.RecordBatch.Index == 0
		case prev.Fragment.Index == next.Fragment.Index:
			return next.RecordBatch.Index == prev.RecordBatch.Index+1
		default:
			return next.Fragment.Index == prev.Fragment.Index+1 &&
				prev.RecordBatch.Last && next.RecordBatch.Index == 0
		}
	}, EnumeratedRecord{Fragment: Enumerated[Fragment]{Index: -1}}), func(in EnumeratedRecord) TaggedRecord {
		return TaggedRecord{
			RecordBatch: in.RecordBatch.Value,
			Fragment:    in.Fragment.Value,
			Err:         in.Err,
		}
	}), nil
}
