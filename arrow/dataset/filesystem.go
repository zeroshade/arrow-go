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
	"io"
	"io/fs"
	"path"
	"strings"

	"github.com/apache/arrow-go/v18/arrow"
	"github.com/substrait-io/substrait-go/expr"
)

type FileFormat interface {
	DefaultFragmentScanOptions() FragmentScanOptions
	TypeName() string
	Equals(FileFormat) bool
	IsSupported(FileSource) (bool, error)
	Inspect(FileSource) (*arrow.Schema, error)
	ScanBatches(context.Context, *ScanOptions, FileFragment) (RecordGenerator, error)
	MakeFragment(FileSource, *arrow.Schema, expr.Expression) (FileFragment, error)
}

type File interface {
	fs.File
	io.ReaderAt
	io.Seeker
}

type FileSource struct {
	Path string
	Info fs.FileInfo

	CustomOpen func() (File, error)
}

func (f FileSource) String() string { return path.Join(f.Path, f.Info.Name()) }

func (f FileSource) Open() (File, error) {
	if f.Info.Sys() != nil {
		fullPath := path.Join(f.Path, f.Info.Name())
		file, err := f.Info.Sys().(fs.FS).Open(fullPath)
		if err != nil {
			return nil, err
		}

		res, ok := file.(File)
		if !ok {
			file.Close()
			return nil, fmt.Errorf("%w: filesystem returned file without ReadAt or Seek for path, %s",
				arrow.ErrInvalid, fullPath)
		}
		return res, nil
	}

	return f.CustomOpen()
}

func (f FileSource) Equals(rhs FileSource) bool {
	return f.Info == rhs.Info && f.Path == rhs.Path
}

type FileFragment interface {
	fmt.Stringer
	Fragment

	Format() FileFormat
	Source() FileSource
	Equals(FileFragment) bool
}

type fileFragment struct {
	source    FileSource
	format    FileFormat
	partition expr.Expression
}

func (f *fileFragment) PartitionExpr() expr.Expression {
	return f.partition
}

func (f *fileFragment) TypeName() string   { return f.format.TypeName() }
func (f *fileFragment) String() string     { return f.source.Path }
func (f *fileFragment) Source() FileSource { return f.source }
func (f *fileFragment) Format() FileFormat { return f.format }
func (f *fileFragment) ReadPhysicalSchema() (*arrow.Schema, error) {
	return f.format.Inspect(f.source)
}
func (f *fileFragment) ScanBatches(ctx context.Context, opts *ScanOptions) (RecordGenerator, error) {
	return f.format.ScanBatches(ctx, opts, f)
}

func (f *fileFragment) Equals(rhs FileFragment) bool {
	return f.format.Equals(rhs.Format()) && f.source.Equals(rhs.Source()) &&
		((f.partition == nil && rhs.PartitionExpr() == nil) || f.partition.Equals(rhs.PartitionExpr()))
}

func NewFileFragment(format FileFormat, fsys fs.StatFS, filepath string) (FileFragment, error) {
	info, err := fsys.Stat(filepath)
	if err != nil {
		return nil, err
	}

	src := FileSource{
		Path: strings.TrimSuffix(filepath, "/"+info.Name()),
		Info: info,
	}

	return format.MakeFragment(src, nil, nil)
}
