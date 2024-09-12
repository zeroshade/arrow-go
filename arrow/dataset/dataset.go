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
	"context"
	"fmt"

	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/compute"
	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/substrait-io/substrait-go/expr"
)

const (
	DefaultBatchSize         = 1 << 17 // 128Ki rows
	DefaultBatchReadahead    = 16
	DefaultFragmentReadahead = 4
)

type RecordMessage struct {
	Record arrow.Record
	Err    error
}

type RecordGenerator <-chan RecordMessage

type FragmentItr func() Fragment

type FragmentScanOptions interface {
	fmt.Stringer
	TypeName() string
	ChannelBufferSize() int
}

type ScanOptions struct {
	Dataset           Dataset
	Filter            expr.Expression
	Columns           []compute.FieldPath
	BatchReadahead    int32
	FragmentReadahead int32
	BatchSize         int64
	Mem               memory.Allocator
	FormatOptions     FragmentScanOptions
}

type Fragment interface {
	ReadPhysicalSchema() (*arrow.Schema, error)
	PartitionExpr() expr.Expression
	TypeName() string
	ScanBatches(context.Context, *ScanOptions) (RecordGenerator, error)
}

type Dataset interface {
	TypeName() string

	GetFragments() (FragmentItr, error)
	GetFragmentsSubset(pred expr.Expression) (FragmentItr, error)

	Schema() *arrow.Schema
	Partition() expr.Expression

	ReplaceSchema(*arrow.Schema) (Dataset, error)
}

type fragmentDataset struct {
	schema    *arrow.Schema
	partition expr.Expression

	fragments []Fragment
}

func (f *fragmentDataset) TypeName() string           { return "fragment" }
func (f *fragmentDataset) Schema() *arrow.Schema      { return f.schema }
func (f *fragmentDataset) Partition() expr.Expression { return f.partition }
func (f *fragmentDataset) ReplaceSchema(schema *arrow.Schema) (Dataset, error) {
	return &fragmentDataset{
		schema:    schema,
		partition: f.partition,
		fragments: f.fragments}, nil
}

func (f *fragmentDataset) GetFragments() (FragmentItr, error) {
	return f.GetFragmentsSubset(nil)
}

func (f *fragmentDataset) GetFragmentsSubset(pred expr.Expression) (FragmentItr, error) {
	if pred != nil {
		return nil, fmt.Errorf("%w: fragment filtering with predicate", arrow.ErrNotImplemented)
	}

	fragIdx := 0
	return func() Fragment {
		if fragIdx < len(f.fragments) {
			result := f.fragments[fragIdx]
			fragIdx++
			return result
		}
		return nil
	}, nil
}
