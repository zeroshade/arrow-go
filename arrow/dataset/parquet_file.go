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
	"errors"
	"fmt"
	"io"
	"io/fs"
	"slices"
	"strings"
	"sync"

	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/compute"
	"github.com/apache/arrow-go/v18/arrow/compute/exprs"
	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/apache/arrow-go/v18/parquet"
	"github.com/apache/arrow-go/v18/parquet/file"
	"github.com/apache/arrow-go/v18/parquet/metadata"
	"github.com/apache/arrow-go/v18/parquet/pqarrow"
	"github.com/substrait-io/substrait-go/expr"
)

const parquetTypeName = "parquet"

type ParquetFragmentScanOptions struct {
	ReaderProps      *parquet.ReaderProperties
	ArrowReaderProps pqarrow.ArrowReadProperties
	ChanBufferSize   int
}

func (pfo ParquetFragmentScanOptions) String() string         { return pfo.TypeName() }
func (ParquetFragmentScanOptions) TypeName() string           { return parquetTypeName }
func (pfo ParquetFragmentScanOptions) ChannelBufferSize() int { return pfo.ChanBufferSize }

func getFragmentScanOptions[T FragmentScanOptions](typeName string, opts *ScanOptions, defaultOpts FragmentScanOptions) (T, error) {
	src := defaultOpts
	if opts != nil && opts.FormatOptions != nil {
		src = opts.FormatOptions
	}

	if src == nil {
		var z T
		return z, nil
	}

	if src.TypeName() != typeName {
		var z T
		return z, fmt.Errorf("%w: FragmentScanOptions of type %s were provided for scanning a fragment of type %s",
			arrow.ErrInvalid, src.TypeName(), typeName)
	}

	out, ok := src.(T)
	if !ok {
		return out, fmt.Errorf("%w: got incorrect type for FragmentScanOptions for type %s",
			arrow.ErrInvalid, typeName)
	}

	return out, nil
}

func makeReaderProps(_ ParquetFileFormat, scanOpts ParquetFragmentScanOptions, alloc memory.Allocator) *parquet.ReaderProperties {
	props := parquet.NewReaderProperties(alloc)
	props.BufferSize = scanOpts.ReaderProps.BufferSize
	props.BufferedStreamEnabled = scanOpts.ReaderProps.BufferedStreamEnabled
	props.FileDecryptProps = scanOpts.ReaderProps.FileDecryptProps

	return props
}

func makeArrowReaderProps(format ParquetFileFormat, metadata *metadata.FileMetaData, opts *ScanOptions, fragmentOptions ParquetFragmentScanOptions) pqarrow.ArrowReadProperties {
	props := pqarrow.ArrowReadProperties{
		Parallel:  fragmentOptions.ArrowReaderProps.Parallel,
		BatchSize: fragmentOptions.ArrowReaderProps.BatchSize,
	}

	if opts.BatchSize != 0 {
		props.BatchSize = opts.BatchSize
	}

	for _, n := range format.ReaderOptions.DictCols {
		idx := metadata.Schema.ColumnIndexByName(n)
		props.SetReadDict(idx, true)
	}

	return props
}

var defaultParquetOptions = ParquetFragmentScanOptions{
	ReaderProps: &parquet.ReaderProperties{},
	ArrowReaderProps: pqarrow.ArrowReadProperties{
		Parallel:  true,
		BatchSize: DefaultBatchSize,
	},
	ChanBufferSize: 4,
}

type ParquetFileFormat struct {
	ReaderOptions struct {
		DictCols []string
	}
}

func (pf ParquetFileFormat) TypeName() string { return parquetTypeName }

func (pf ParquetFileFormat) DefaultFragmentScanOptions() FragmentScanOptions {
	return defaultParquetOptions
}

func (pf ParquetFileFormat) GetReader(src FileSource, opts *ScanOptions, meta *metadata.FileMetaData) (*pqarrow.FileReader, error) {
	scanOpts, err := getFragmentScanOptions[ParquetFragmentScanOptions](parquetTypeName,
		opts, defaultParquetOptions)
	if err != nil {
		return nil, err
	}

	props := makeReaderProps(pf, scanOpts, opts.Mem)
	input, err := src.Open()
	if err != nil {
		return nil, err
	}

	rdr, err := file.NewParquetReader(input,
		file.WithReadProps(props), file.WithMetadata(meta))
	if err != nil {
		return nil, err
	}

	readerMeta := rdr.MetaData()
	arrowProps := makeArrowReaderProps(pf, readerMeta, opts, scanOpts)
	return pqarrow.NewFileReader(rdr, arrowProps, opts.Mem)
}

func (pf ParquetFileFormat) IsSupported(src FileSource) (bool, error) {
	input, err := src.Open()
	if err != nil {
		return false, err
	}
	defer input.Close()

	options := defaultParquetOptions
	rdr, err := file.NewParquetReader(input, file.WithReadProps(options.ReaderProps))
	if err != nil {
		return false, err
	}
	defer rdr.Close()

	return true, nil
}

func (pf ParquetFileFormat) Inspect(src FileSource) (*arrow.Schema, error) {
	var scanOpts ScanOptions
	rdr, err := pf.GetReader(src, &scanOpts, nil)
	if err != nil {
		return nil, err
	}
	defer rdr.ParquetReader().Close()

	return rdr.Schema()
}

func (pf ParquetFileFormat) Equals(other FileFormat) bool {
	if pf.TypeName() != other.TypeName() {
		return false
	}

	rhs, ok := other.(ParquetFileFormat)
	if !ok {
		return false
	}

	return slices.Equal(pf.ReaderOptions.DictCols, rhs.ReaderOptions.DictCols)
}

func inferColumnProjection(rdr *pqarrow.FileReader, opts *ScanOptions) []int {
	// no columns specified, assume all columns being read
	if len(opts.Columns) == 0 {
		return nil
	}

	manifest := rdr.Manifest
	refs := exprs.FieldsInExpression(opts.Filter)
	for _, c := range opts.Columns {
		refs = append(refs, expr.FieldReference{
			Reference: exprs.RefFromFieldPath(c),
			Root:      expr.RootReference,
		})
	}

	indices := make([]int, len(refs))
	for i, r := range refs {
		if r.Reference.(expr.ReferenceSegment).GetChild() != nil {
			return nil
		}

		indices[i] = int(r.Reference.(expr.ReferenceSegment).(*expr.StructFieldRef).Field)
	}

	out, _ := manifest.GetFieldIndices(indices)
	return out

	// // Build a lookup table from top level field name to field metadata.
	// // This is to avoid quadratic-time mapping of projected fields to
	// // column indices, in the common case of selecting top level
	// // columns. For nested fields, we will pay the cost of a linear scan
	// // assuming for now that this is relatively rare, but this can be
	// // optimized. (Also, we don't want to pay the cost of building all
	// // the lookup tables up front if they're rarely used.)
	// fieldLookup, duplicates := map[string]pqarrow.SchemaField{}, map[string]struct{}{}
	// for _, schemaField := range manifest.Fields {
	// 	n := schemaField.Field.Name
	// 	_, ok := fieldLookup[n]
	// 	if ok {
	// 		duplicates[n] = struct{}{}
	// 	}
	// 	fieldLookup[n] = schemaField
	// }

	// TODO implement this
	// for now we always retrieve all columns
	return nil
}

func (pf ParquetFileFormat) ScanBatches(ctx context.Context, opts *ScanOptions, frag FileFragment) (RecordGenerator, error) {
	parquetFrag, ok := frag.(*ParquetFileFragment)
	if !ok {
		return nil, fmt.Errorf("%w: ParquetFileFormat can only process ParquetFileFragments, got %s",
			arrow.ErrInvalid, frag.TypeName())
	}

	var (
		preFiltered = false
		rowGroups   []int
		err         error
	)

	// if rowgroup metadata is cached completely we can pre-filter rowgroups before opening
	// the filereader, potentially avoiding IO altogether if all RowGroups are excluded due
	// to stats knowledge. In the case where a row group doesn't have statistics metadata,
	// it will not be excluded.
	// currently filtering isn't implemented yet, and will just return all the row groups
	if parquetFrag.Metadata() != nil {
		rowGroups, err = parquetFrag.filterRowGroups(opts.Filter)
		if err != nil {
			return nil, err
		}

		preFiltered = true
		if len(rowGroups) == 0 {
			ch := make(chan RecordMessage, 1)
			ch <- RecordMessage{}
			defer close(ch)
			return ch, nil
		}
	}

	if opts.FormatOptions == nil {
		opts.FormatOptions = pf.DefaultFragmentScanOptions()
	}

	bufSize := opts.FormatOptions.ChannelBufferSize()
	if bufSize <= 0 {
		bufSize = 1
	}

	ch := make(chan RecordMessage, bufSize)
	go func() {
		defer close(ch)

		rdr, err := pf.GetReader(parquetFrag.source, opts, parquetFrag.Metadata())
		if err != nil {
			ch <- RecordMessage{Err: err}
			return
		}
		defer rdr.ParquetReader().Close()

		if err = parquetFrag.ensureCompleteMetadata(rdr); err != nil {
			ch <- RecordMessage{Err: err}
			return
		}

		if !preFiltered {
			rowGroups, err = parquetFrag.filterRowGroups(opts.Filter)
			if err != nil {
				ch <- RecordMessage{Err: err}
				return
			}

			if len(rowGroups) == 0 {
				ch <- RecordMessage{}
				return
			}
		}

		colList := inferColumnProjection(rdr, opts)
		rdr.Props.BatchSize = int64(opts.BatchReadahead) * opts.BatchSize
		recRdr, err := rdr.GetRecordReader(ctx, colList, rowGroups)
		if err != nil {
			ch <- RecordMessage{Err: err}
			return
		}
		defer recRdr.Release()

		for recRdr.Next() {
			rec := recRdr.Record()
			if opts.Filter != nil {
				input := compute.NewDatumWithoutOwning(rec)
				mask, err := exprs.ExecuteScalarExpression(ctx, rec.Schema(),
					opts.Filter, input)
				if err != nil {
					ch <- RecordMessage{Err: err}
					return
				}
				result, err := compute.Filter(ctx, input, mask, *compute.DefaultFilterOptions())
				if err != nil {
					ch <- RecordMessage{Err: err}
					return
				}

				mask.Release()
				rec = result.(*compute.RecordDatum).Value
			}

			if rec.NumRows() <= opts.BatchSize {
				rec.Retain()
				ch <- RecordMessage{Record: rec}
				continue
			}

			for i := int64(0); i < rec.NumRows(); i += opts.BatchSize {
				end := min(rec.NumRows(), i+opts.BatchSize)
				ch <- RecordMessage{Record: rec.NewSlice(i, end)}
			}
		}

		if recRdr.Err() != nil && !errors.Is(recRdr.Err(), io.EOF) {
			ch <- RecordMessage{Err: recRdr.Err()}
		}
	}()
	return ch, nil
}

func (pf ParquetFileFormat) FragmentFromFile(fsys fs.StatFS, filepath string, partitionExpr expr.Expression) (Fragment, error) {
	info, err := fsys.Stat(filepath)
	if err != nil {
		return nil, err
	}

	return &ParquetFileFragment{
		fileFragment: fileFragment{
			source: FileSource{
				Path: strings.TrimSuffix(filepath, info.Name()),
				Info: info,
			},
			format:    pf,
			partition: partitionExpr,
		},
		parquetFormat: &pf,
	}, nil
}

func (pf ParquetFileFormat) MakeFragment(src FileSource, physicalSchema *arrow.Schema, partitionExpr expr.Expression) (FileFragment, error) {
	return &ParquetFileFragment{
		fileFragment: fileFragment{
			source:    src,
			format:    pf,
			partition: partitionExpr,
		},
		parquetFormat: &pf,
	}, nil
}

type ParquetFileFragment struct {
	fileFragment
	schemaMx       sync.Mutex
	physicalSchema *arrow.Schema

	metadata  *metadata.FileMetaData
	RowGroups []int

	parquetFormat *ParquetFileFormat
	manifest      *pqarrow.SchemaManifest
}

func (p *ParquetFileFragment) ScanBatches(ctx context.Context, opts *ScanOptions) (RecordGenerator, error) {
	return p.format.ScanBatches(ctx, opts, p)
}

func (p *ParquetFileFragment) Metadata() *metadata.FileMetaData {
	p.schemaMx.Lock()
	defer p.schemaMx.Unlock()
	return p.metadata
}

func (p *ParquetFileFragment) setMetadata(metadata *metadata.FileMetaData, manifest *pqarrow.SchemaManifest) error {
	p.metadata, p.manifest = metadata, manifest
	numRowGroups := len(metadata.RowGroups)
	for _, rg := range p.RowGroups {
		if rg < numRowGroups {
			continue
		}

		return fmt.Errorf("index error")
	}

	return nil
}

func (p *ParquetFileFragment) ensureCompleteMetadata(rdr *pqarrow.FileReader) error {
	p.schemaMx.Lock()
	if p.metadata != nil {
		p.schemaMx.Unlock()
		return nil
	}

	if rdr == nil {
		p.schemaMx.Unlock()
		opts := ScanOptions{}
		rdr, err := p.parquetFormat.GetReader(p.source, &opts, p.metadata)
		if err != nil {
			return err
		}
		defer rdr.ParquetReader().Close()
		return p.ensureCompleteMetadata(rdr)
	}

	defer p.schemaMx.Unlock()
	sc, err := rdr.Schema()
	if err != nil {
		return err
	}

	if p.physicalSchema != nil && !p.physicalSchema.Equal(sc) {
		return fmt.Errorf("%w: fragment initialized with physical schema \n%s but %s has schema \n%s",
			arrow.ErrInvalid, p.physicalSchema, p.source, sc)
	}

	p.physicalSchema = sc
	if len(p.RowGroups) == 0 {
		p.RowGroups = make([]int, rdr.ParquetReader().NumRowGroups())
		for i := 0; i < rdr.ParquetReader().NumRowGroups(); i++ {
			p.RowGroups[i] = i
		}
	}

	p.manifest = rdr.Manifest
	return p.setMetadata(rdr.ParquetReader().MetaData(), rdr.Manifest)
}

func (p *ParquetFileFragment) filterRowGroups(pred expr.Expression) ([]int, error) {
	// TODO implement filtering by checking against statistics of row groups
	// for now return ALL row groups
	rgInfo := p.Metadata().RowGroups
	out := make([]int, len(rgInfo))
	for i := range rgInfo {
		out[i] = i
	}
	return out, nil
}
