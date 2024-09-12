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

	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/array"
	"github.com/apache/arrow-go/v18/arrow/compute"
	"github.com/apache/arrow-go/v18/arrow/compute/exprs"
	"github.com/substrait-io/substrait-go/expr"
)

type inMemoryFragment struct {
	schema    *arrow.Schema
	batches   []arrow.Record
	partition expr.Expression
}

func (f *inMemoryFragment) ReadPhysicalSchema() (*arrow.Schema, error) {
	return f.schema, nil
}

func (f *inMemoryFragment) TypeName() string               { return "in-memory" }
func (f *inMemoryFragment) PartitionExpr() expr.Expression { return f.partition }

func (f *inMemoryFragment) ScanBatches(ctx context.Context, opts *ScanOptions) (RecordGenerator, error) {
	bufSize := opts.FormatOptions.ChannelBufferSize()
	if bufSize <= 0 {
		bufSize = 1
	}

	outputSchema := f.schema
	if len(opts.Columns) > 0 {
		fields := make([]arrow.Field, len(opts.Columns))
		for i, c := range opts.Columns {
			field, err := c.Get(f.schema)
			if err != nil {
				return nil, err
			}

			fields[i] = *field
		}
		outputSchema = arrow.NewSchema(fields, nil)
	}

	selectCols := func(r arrow.Record) (arrow.Record, error) {
		resultCols := make([]arrow.Array, len(opts.Columns))
		for i, sc := range opts.Columns {
			col, err := sc.GetColumn(r)
			if err != nil {
				return nil, err
			}

			resultCols[i] = col
		}
		return array.NewRecord(outputSchema, resultCols, r.NumRows()), nil
	}

	ch := make(chan RecordMessage, bufSize)
	go func() {
		defer close(ch)
		var err error
		for _, rec := range f.batches {
			if opts.Filter != nil {
				result, err := exprs.ExecuteScalarExpression(ctx, rec.Schema(),
					opts.Filter, compute.NewDatumWithoutOwning(rec))
				if err != nil {
					ch <- RecordMessage{Err: err}
					return
				}

				rec = result.(*compute.RecordDatum).Value
			} else if len(opts.Columns) == 0 {
				rec.Retain()
			}

			if len(opts.Columns) != 0 {
				rec, err = selectCols(rec)
				if err != nil {
					ch <- RecordMessage{Err: err}
					break
				}
			}
			ch <- RecordMessage{Record: rec}
		}
	}()
	return ch, nil
}
